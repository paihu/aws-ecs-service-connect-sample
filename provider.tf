provider "aws" {
  default_tags {
    tags = {
      Name             = "service connect test"
      TerraformManaged = "true"
    }
  }
}
