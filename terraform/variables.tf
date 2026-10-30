variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH to the ECS instances. Set in terraform.tfvars, which git ignores."
  type        = string
}
