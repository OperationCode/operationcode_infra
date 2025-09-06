
data "aws_secretsmanager_secret" "ecs" {
  name = "${var.env}/python_backend"
}

data "aws_secretsmanager_secret_version" "ecs-secrets" {
  secret_id = data.aws_secretsmanager_secret.ecs.id
}

locals {
  long_env_name = var.env == "prod" ? "production" : var.env

  # CHANGEME once infra scales up
  cpu    = var.env == "prod" ? 256 : 256
  memory = var.env == "prod" ? 512 : 384
  count  = var.env == "prod" ? 1 : 1


  # Takes all of the keys from the secret manager k/v store and turns them into a map suitable for use in the container definition
  # manage at https://us-east-2.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-2
  secrets     = jsondecode(data.aws_secretsmanager_secret_version.ecs-secrets.secret_string)
  secrets_env = nonsensitive(toset([for i, v in local.secrets : tomap({ "name" = upper(i), "valueFrom" = "${data.aws_secretsmanager_secret.ecs.arn}:${i}::" })]))
}


resource "aws_ecs_task_definition" "python_backend" {
  family             = "python_backend_${var.env}"
  execution_role_arn = var.task_execution_role
  network_mode       = "bridge"
  cpu                = local.cpu
  memory             = local.memory

  container_definitions = jsonencode([
    {
      name      = "python_backend_${var.env}"
      image     = "633607774026.dkr.ecr.us-east-2.amazonaws.com/back-end:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.logs_group
          awslogs-region        = "us-east-2"
          awslogs-stream-prefix = "python_backend_${var.env}"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:8000/healthz"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      environment = [
        {
          "name" : "ENVIRONMENT",
          "value" : "aws_ecs_${var.env}"
        },
        {
          "name" : "EXTRA_HOSTS",
          "value" : "*"
        },
        {
          "name" : "RELEASE",
          "value" : "1.0.1"
        },
        {
          "name" : "SITE_ID",
          "value" : "4"
        },
        {
          "name" : "DJANGO_ENV",
          "value" : "${local.long_env_name}"
        },
        {
          "name" : "GITHUB_REPO",
          "value" : "operationcode/back-end"
        },
        {
          "name" : "HONEYCOMB_DATASET",
          "value" : "${local.long_env_name}-traces"
        },
        {
          "name" : "DB_ENGINE",
          "value" : "django.db.backends.postgresql"
        },
      ]

      secrets = local.secrets_env

      mountPoints = []
      volumesFrom = []
  }])
}

resource "aws_ecs_service" "python_backend" {
  name            = "python_backend_${var.env}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.python_backend.arn

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
    target_group_arn = aws_lb_target_group.python_backend.arn
    container_name   = "python_backend_${var.env}"
    container_port   = 8000
  }
}

# Load balancer Target group
resource "aws_lb_target_group" "python_backend" {
  name = "ecs-python-backend-${var.env}"

  port        = 8000
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

  deregistration_delay = 10
}
