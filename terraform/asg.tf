
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
}

# https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/latest
module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  name             = "${local.name}-spot"
  instance_type    = "t3.small"
  min_size         = 1
  max_size         = 2
  desired_capacity = 1
  instance_market_options = {
    market_type = "spot"
  }

  image_id                        = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  user_data                       = base64encode(local.user_data)
  ignore_desired_capacity_changes = true
  key_name                        = "oc-ops"

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = data.aws_subnets.use2.ids
  health_check_type   = "EC2"
  network_interfaces = [
    {
      delete_on_termination       = true
      device_index                = 0
      associate_public_ip_address = false
      security_groups             = [module.autoscaling_sg.security_group_id]
    }
  ]

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = false
        volume_size           = 30
        volume_type           = "gp3"
      }
    }
  ]

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = false

  # reduce cloudwatch costs
  enable_monitoring = false

  tags = local.tags
}

# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest
module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Autoscaling group security group"
  vpc_id      = data.aws_vpc.use2.id

  # Inbound admin ssh
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "73.37.119.155/32"
    }
  ]

  # Inbound all high ports from the alb
  ingress_with_source_security_group_id = [
    {
      source_security_group_id = aws_security_group.lb_security_group.id
      from_port                = 1024
      to_port                  = 65535
      protocol                 = "tcp"
    }
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}

data "aws_vpc" "use2" {
  id = "vpc-193af371"
}

data "aws_subnets" "use2" {
  filter {
    name   = "vpc-id"
    values = ["vpc-193af371"]
  }
}
