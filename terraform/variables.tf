variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH to the ECS instances. Set in terraform.tfvars, which git ignores."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_ssh_cidr, 0)) && endswith(var.admin_ssh_cidr, "/32")
    error_message = "admin_ssh_cidr must be a single IPv4 address in CIDR form, such as 203.0.113.10/32."
  }
}
