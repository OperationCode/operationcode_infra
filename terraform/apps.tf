resource "aws_cloudwatch_log_group" "ecslogs" {
  name_prefix       = "ecs-"
  retention_in_days = 7
}

# Secrets access stuff
################################################################################
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# attach aws secrets manager policy to ecs task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attach" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# The Apps
################################################################################

# Backend Prod
module "python_backend_prod" {
  source = "./python_backend"

  env                 = "prod"
  vpc_id              = data.aws_vpc.use2.id
  logs_group          = aws_cloudwatch_log_group.ecslogs.name
  ecs_cluster_id      = module.ecs.cluster_id
  task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_lb_listener_rule" "python_backend_prod" {
  listener_arn = aws_lb_listener.default_https.arn

  action {
    type             = "forward"
    target_group_arn = module.python_backend_prod.lb_tg_arn
  }

  condition {
    host_header {
      values = ["backend.operationcode.org", "api.operationcode.org"]
    }
  }
}

# Backend Staging
module "python_backend_staging" {
  source = "./python_backend"

  env                 = "staging"
  vpc_id              = data.aws_vpc.use2.id
  logs_group          = aws_cloudwatch_log_group.ecslogs.name
  ecs_cluster_id      = module.ecs.cluster_id
  task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_lb_listener_rule" "python_backend_staging" {
  listener_arn = aws_lb_listener.default_https.arn

  action {
    type             = "forward"
    target_group_arn = module.python_backend_staging.lb_tg_arn
  }

  condition {
    host_header {
      values = ["backend-staging.operationcode.org", "api.staging.operationcode.org"]
    }
  }
}

# Resources API prod
module "resources_api_prod" {
  source = "./resources_api"

  env                 = "prod"
  vpc_id              = data.aws_vpc.use2.id
  logs_group          = aws_cloudwatch_log_group.ecslogs.name
  ecs_cluster_id      = module.ecs.cluster_id
  task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_lb_listener_rule" "resources_api_prod" {
  listener_arn = aws_lb_listener.default_https.arn

  action {
    type             = "forward"
    target_group_arn = module.resources_api_prod.lb_tg_arn
  }

  condition {
    host_header {
      values = ["resources.operationcode.org"]
    }
  }
}

# Resources API staging
module "resources_api_staging" {
  source = "./resources_api"

  env                 = "staging"
  vpc_id              = data.aws_vpc.use2.id
  logs_group          = aws_cloudwatch_log_group.ecslogs.name
  ecs_cluster_id      = module.ecs.cluster_id
  task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_lb_listener_rule" "resources_api_staging" {
  listener_arn = aws_lb_listener.default_https.arn

  action {
    type             = "forward"
    target_group_arn = module.resources_api_staging.lb_tg_arn
  }

  condition {
    host_header {
      values = ["resources.staging.operationcode.org", "resources-staging.operationcode.org"]
    }
  }
}
