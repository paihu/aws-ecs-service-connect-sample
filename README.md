# AWS ECS Service Connect Sample

## require
* terraform ~>1.3.0
* aws-provider ~>4.45.0
* aws cli v2

## usage
1. terraform init
2. terraform apply
3. aws ecs list-tasks --cluster service-connect-test
4. aws ecs execute-command --interactive --command /bin/bash --container nginx --cluster service-connect-test --task <task_id from 3.>
5. (ecs-task)# cat /etc/hosts
6. (ecs-task)# curl nginx.service_connect

## finished
terraform destroy

