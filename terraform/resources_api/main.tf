data "aws_secretsmanager_secret" "ecs" {
  name = "${var.env}/resources_api"
}

data "aws_secretsmanager_secret_version" "ecs-secrets" {
  secret_id = data.aws_secretsmanager_secret.ecs.id
}

locals {
  long_env_name = var.env == "prod" ? "production" : var.env

  # CHANGEME once infra scales up
  cpu    = var.env == "prod" ? 256 : 256
  memory = var.env == "prod" ? 256 : 128
  count  = var.env == "prod" ? 1 : 1


  # Takes all of the keys from the secret manager k/v store and turns them into a map suitable for use in the container definition
  # manage at https://us-east-2.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-2
  secrets     = jsondecode(data.aws_secretsmanager_secret_version.ecs-secrets.secret_string)
  secrets_env = nonsensitive(toset([for i, v in local.secrets : tomap({ "name" = upper(i), "valueFrom" = "${data.aws_secretsmanager_secret.ecs.arn}:${i}::" })]))
}


resource "aws_ecs_task_definition" "resources_api" {
  family             = "resources_api_${var.env}"
  execution_role_arn = var.task_execution_role
  network_mode       = "bridge"
  cpu                = local.cpu
  memory             = local.memory

  container_definitions = jsonencode([
    {
      name      = "resources_api_${var.env}"
      image     = "operationcode/resources-api:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.logs_group
          awslogs-region        = "us-east-2"
          awslogs-stream-prefix = "resources_api_${var.env}"
        }
      }

      secrets = local.secrets_env

      mountPoints = []
      volumesFrom = []
  }])
}

resource "aws_ecs_service" "resources_api" {
  name            = "resources_api_${var.env}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.resources_api.arn

  desired_count = local.count

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  capacity_provider_strategy {
    base              = 20
    capacity_provider = "spot_instances"
    weight            = 60
  }

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.resources_api.arn
    container_name   = "resources_api_${var.env}"
    container_port   = 5000
  }
}

# Load balancer Target group
resource "aws_lb_target_group" "resources_api" {
  name = "ecs-resources-api-${var.env}"

  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/healthz"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 300
}
