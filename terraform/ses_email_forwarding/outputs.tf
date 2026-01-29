output "lambda_function_arn" {
  description = "ARN of the SES email forwarder Lambda function"
  value       = aws_lambda_function.ses_email_forwarder.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ses_email_forwarder.function_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing incoming emails"
  value       = aws_s3_bucket.incoming_emails.id
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for DNS configuration"
  value       = aws_ses_domain_dkim.coders.dkim_tokens
}

output "ses_receipt_rule_set_name" {
  description = "Name of the SES receipt rule set"
  value       = aws_ses_receipt_rule_set.main.rule_set_name
}

output "ses_domain_identity" {
  description = "The domain identity verified in SES"
  value       = aws_ses_domain_identity.coders.domain
}
