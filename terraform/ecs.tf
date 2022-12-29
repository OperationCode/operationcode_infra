provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  region     = "us-east-2"
  name       = "operationcode-ecs-us-east-2"
  account_id = data.aws_caller_identity.current.account_id

  user_data = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    ECS_LOGLEVEL=debug
    ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true
    EOF
  EOT

  tags = {
    Name       = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-ecs"
  }
}

################################################################################
# ECS Module
################################################################################

# https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws/latest
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4.0"

  cluster_name = local.name

  cluster_configuration = {
    execute_command_configuration = {
      # logging = "OVERRIDE"
      # log_configuration = {
      #   # You can set a simple string and ECS will create the CloudWatch log group for you
      #   # or you can create the resource yourself as shown here to better manage retetion, tagging, etc.
      #   # Embedding it into the module is not trivial and therefore it is externalized
      #   cloud_watch_log_group_name = aws_cloudwatch_log_group.this.name
      # }
    }
  }

  default_capacity_provider_use_fargate = false

  # Capacity provider - Fargate
  fargate_capacity_providers = {
    FARGATE      = {}
    FARGATE_SPOT = {}
  }

  # Capacity provider - autoscaling groups
  autoscaling_capacity_providers = {
    spot_instances = {
      auto_scaling_group_arn         = module.autoscaling.autoscaling_group_arn
      managed_termination_protection = "DISABLED"

      managed_scaling = {
        maximum_scaling_step_size = 3
        minimum_scaling_step_size = 1
        status                    = "DISABLED"
        target_capacity           = 80
      }

      default_capacity_provider_strategy = {
        weight = 60
        base   = 20
      }
    }
  }

  tags = local.tags
}


################################################################################
# Supporting Resources
################################################################################
