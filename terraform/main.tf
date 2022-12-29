terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.6"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "operationcode-infra-config"
    key    = "ecs/terraform.tfstate"
    region = "us-east-2"
  }
}
