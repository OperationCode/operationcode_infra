# Operation Code Infrastructure

Terraform-managed AWS infrastructure for [Operation Code](https://operationcode.org/).

## Overview

ECS cluster running containerized services on EC2 spot instances, fronted by an Application Load Balancer.

### Active Services
- **Python Backend** (prod/staging) - `backend.operationcode.org`, `api.operationcode.org`
- **Pybot** (prod) - Slack integration bot at `pybot.operationcode.org`

### Stack
- **Region:** us-east-2
- **Compute:** ECS with Fargate + spot instances
- **Routing:** ALB with host-based routing
- **Logs:** CloudWatch (7-day retention)
- **State:** S3 backend

## Structure
```
terraform/
├── ecs.tf           # ECS cluster config
├── apps.tf          # Service definitions
├── alb.tf           # Load balancer
├── asg.tf           # Auto-scaling groups
├── python_backend/  # Backend service module
└── pybot/           # Pybot service module
```

## License
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Operation Code Infra is under the [MIT License](/LICENSE).
