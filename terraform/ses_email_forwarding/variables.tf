variable "domain" {
  description = "Domain for email forwarding (e.g., coders.operationcode.org)"
  type        = string
}

variable "forward_from_email" {
  description = "From address for forwarded emails (must be verified SES identity)"
  type        = string
}

variable "environment" {
  description = "Environment name (prod/staging)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "airtable_secret_name" {
  description = "Name of secret in Secrets Manager containing Airtable credentials"
  type        = string
}
