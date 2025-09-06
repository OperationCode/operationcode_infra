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
  image_tag           = "latest"
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
# module "python_backend_staging" {
#   source = "./python_backend"

#   env                 = "staging"
#   vpc_id              = data.aws_vpc.use2.id
#   logs_group          = aws_cloudwatch_log_group.ecslogs.name
#   ecs_cluster_id      = module.ecs.cluster_id
#   task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
#   image_tag           = "latest"
# }

# resource "aws_lb_listener_rule" "python_backend_staging" {
#   listener_arn = aws_lb_listener.default_https.arn

#   action {
#     type             = "forward"
#     target_group_arn = module.python_backend_staging.lb_tg_arn
#   }

#   condition {
#     host_header {
#       values = ["backend-staging.operationcode.org", "api.staging.operationcode.org"]
#     }
#   }
# }

# Redirector for shut down sites
resource "aws_lb_listener_rule" "shutdown_sites_redirector" {
  listener_arn = aws_lb_listener.default_https.arn

  action {
    type = "redirect"

    redirect {
      host        = "www.operationcode.org"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = [
        "resources.operationcode.org",
        "resources-staging.operationcode.org",
        "api.staging.operationcode.org",
      ]
    }
  }
}


# Resources API has been shut down
# # Resources API prod
# module "resources_api_prod" {
#   source = "./resources_api"

#   env                 = "prod"
#   vpc_id              = data.aws_vpc.use2.id
#   logs_group          = aws_cloudwatch_log_group.ecslogs.name
#   ecs_cluster_id      = module.ecs.cluster_id
#   task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
#   image_tag           = "202b27d4a8be4418089469e1c79e04277268962e"
# }

# resource "aws_lb_listener_rule" "resources_api_prod" {
#   listener_arn = aws_lb_listener.default_https.arn

#   action {
#     type             = "forward"
#     target_group_arn = module.resources_api_prod.lb_tg_arn
#   }

#   condition {
#     host_header {
#       values = ["resources.operationcode.org"]
#     }
#   }
# }

# # Resources API staging
# module "resources_api_staging" {
#   source = "./resources_api"

#   env                 = "staging"
#   vpc_id              = data.aws_vpc.use2.id
#   logs_group          = aws_cloudwatch_log_group.ecslogs.name
#   ecs_cluster_id      = module.ecs.cluster_id
#   task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
#   image_tag           = "fb8c59d54a5a4aed9f9cf58144eecee69f9fc58e"
# }

# resource "aws_lb_listener_rule" "resources_api_staging" {
#   listener_arn = aws_lb_listener.default_https.arn

#   action {
#     type             = "forward"
#     target_group_arn = module.resources_api_staging.lb_tg_arn
#   }

#   condition {
#     host_header {
#       values = ["resources.staging.operationcode.org", "resources-staging.operationcode.org"]
#     }
#   }
# }


# note: pybot moving off to Render.com
# Pybot staging
# module "pybot_staging" {
#   source = "./pybot"

#   env                 = "staging"
#   vpc_id              = data.aws_vpc.use2.id
#   logs_group          = aws_cloudwatch_log_group.ecslogs.name
#   ecs_cluster_id      = module.ecs.cluster_id
#   task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
#   image_tag           = "staging"
# }

# resource "aws_lb_listener_rule" "pybot_staging" {
#   listener_arn = aws_lb_listener.default_https.arn

#   action {
#     type             = "forward"
#     target_group_arn = module.pybot_staging.lb_tg_arn
#   }

#   condition {
#     host_header {
#       values = ["pybot.staging.operationcode.org"]
#     }
#   }

#   condition {
#     path_pattern {
#       values = ["/slack/*", "/pybot/*", "/airtable/*"]
#     }
#   }
# }

# Pybot Prod
module "pybot_prod" {
  source = "./pybot"

  env                 = "prod"
  vpc_id              = data.aws_vpc.use2.id
  logs_group          = aws_cloudwatch_log_group.ecslogs.name
  ecs_cluster_id      = module.ecs.cluster_id
  task_execution_role = data.aws_iam_role.ecs_task_execution_role.arn
  image_tag           = "latest"
}

resource "aws_lb_listener_rule" "pybot_prod" {
  listener_arn = aws_lb_listener.default_https.arn

  action {
    type             = "forward"
    target_group_arn = module.pybot_prod.lb_tg_arn
  }

  condition {
    host_header {
      values = ["pybot.operationcode.org"]
    }
  }

  condition {
    path_pattern {
      values = ["/slack/*", "/pybot/*", "/airtable/*"]
    }
  }
}
