data "aws_caller_identity" "this" {}
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

}

resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_subnet" "this" {
  count      = 3
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.${count.index}.0/24"
}

resource "aws_service_discovery_http_namespace" "this" {
  name        = "service_connect"
  description = "service_connect"
}

resource "aws_ecs_cluster" "this" {
  name = "service-connect-test"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }

  }
}
resource "aws_iam_role" "this" {
  name               = "service_connect_test_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
resource "aws_iam_role_policy_attachment" "ECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "SSMManagedInstanceCore" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "service-connect-test"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.this.arn
  task_role_arn            = aws_iam_role.this.arn
  container_definitions = jsonencode([
    {
      name  = "nginx"
      image = "public.ecr.aws/nginx/nginx:latest"
      portMappings = [
        {
          name          = "nginx"
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "target" {
  name                   = "target"
  cluster                = aws_ecs_cluster.this.id
  enable_execute_command = true
  capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.this.arn
    service {
      client_alias {
        port = "80"
      }
      port_name = "nginx"
    }
  }
  network_configuration {
    subnets          = aws_subnet.this.*.id
    assign_public_ip = true

  }
}

resource "aws_ecs_service" "source" {
  name                   = "source"
  cluster                = aws_ecs_cluster.this.id
  enable_execute_command = true
  capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.this.arn
  }
  network_configuration {
    subnets          = aws_subnet.this.*.id
    assign_public_ip = true

  }
}
