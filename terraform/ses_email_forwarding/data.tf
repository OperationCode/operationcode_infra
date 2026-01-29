# Package Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/ses_email_forwarder"
  output_path = "${path.module}/lambda_function.zip"

  excludes = [
    "tests",
    "tests/*",
    "README.md",
    "__pycache__",
    "__pycache__/*",
    "*.pyc",
    ".pytest_cache",
    ".pytest_cache/*",
    ".coverage",
    ".coverage.*",
    "htmlcov",
    "htmlcov/*",
    ".venv",
    ".venv/*",
    "venv",
    "venv/*"
  ]
}

# Reference Secrets Manager secret (in us-east-2)
# Note: We construct the ARN manually since the secret is in a different region
# Lambda in us-east-1 can access secrets in us-east-2 cross-region
locals {
  secret_arn = "arn:aws:secretsmanager:us-east-2:${var.account_id}:secret:${var.airtable_secret_name}-*"
}
