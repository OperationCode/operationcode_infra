variable "env" {
  type        = string
  description = "The name of the environment"
  default     = "prod"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
}

variable "logs_group" {
  type        = string
  description = "The name of the log group"
}

variable "ecs_cluster_id" {
  type        = string
  description = "The ID of the ECS cluster"
}

variable "task_execution_role" {
  type        = string
  description = "The name of the ECS task execution role"
}
