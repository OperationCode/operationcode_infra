# load balancer ARN  arn:aws:acm:us-east-2:633607774026:certificate/8de9fd02-191c-485f-b952-e5ba32e90acb
################################################################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "lb_security_group" {
  name_prefix = "ecs"
  vpc_id      = data.aws_vpc.use2.id

  # allow incoming traffic
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # allow all outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.use2.cidr_block]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "ecs" {
  name_prefix     = "oc"
  security_groups = [aws_security_group.lb_security_group.id]
  access_logs {
    bucket  = "oc-alb-logs"
    enabled = true
    prefix  = "2025"
  }

  load_balancer_type = "application"
  internal           = false
  ip_address_type    = "dualstack"

  subnets = data.aws_subnets.use2.ids

  # idle_timeout = 60
}


resource "aws_lb_listener" "default_http" {
  depends_on = [aws_lb.ecs]

  load_balancer_arn = aws_lb.ecs.arn
  protocol          = "HTTP"
  port              = 80

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_lb_listener" "default_https" {
  depends_on = [aws_lb.ecs]

  load_balancer_arn = aws_lb.ecs.arn
  protocol          = "HTTPS"
  port              = 443
  certificate_arn   = "arn:aws:acm:us-east-2:633607774026:certificate/cebe8639-6144-409d-b384-c0b4b4880898"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}
