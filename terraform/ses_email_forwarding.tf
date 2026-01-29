# SES Email Forwarding Module
# Note: aws_caller_identity.current is defined in ecs.tf
# All resources in this module are deployed to us-east-1
module "ses_email_forwarder" {
  source = "./ses_email_forwarding"

  providers = {
    aws = aws.us_east_1 # All resources in this module use us-east-1
  }

  domain               = "coders.operationcode.org"
  forward_from_email   = "noreply@coders.operationcode.org"
  environment          = "prod"
  account_id           = data.aws_caller_identity.current.account_id
  airtable_secret_name = "prod/ses_email_forwarder" # In us-east-2, cross-region access
}

# Outputs
output "ses_email_forwarder_lambda_arn" {
  description = "ARN of the SES email forwarder Lambda function"
  value       = module.ses_email_forwarder.lambda_function_arn
}

output "ses_email_forwarder_bucket" {
  description = "S3 bucket storing incoming emails"
  value       = module.ses_email_forwarder.s3_bucket_name
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for DNS configuration"
  value       = module.ses_email_forwarder.ses_dkim_tokens
}

output "ses_mail_from_domain" {
  description = "Custom MAIL FROM domain for DMARC alignment"
  value       = module.ses_email_forwarder.mail_from_domain
}

output "ses_mail_from_dns_records" {
  description = "DNS records required for custom MAIL FROM domain"
  value = {
    mx_record  = "MX: ${module.ses_email_forwarder.mail_from_domain} -> ${module.ses_email_forwarder.mail_from_mx_record}"
    spf_record = "TXT: ${module.ses_email_forwarder.mail_from_domain} -> ${module.ses_email_forwarder.mail_from_spf_record}"
  }
}
