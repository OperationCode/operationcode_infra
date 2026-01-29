# S3 Bucket for storing incoming emails
resource "aws_s3_bucket" "incoming_emails" {
  bucket = "opcode-ses-incoming-emails"

  tags = {
    Name        = "SES Incoming Emails"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket lifecycle rule - delete emails after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "incoming_emails" {
  bucket = aws_s3_bucket.incoming_emails.id

  rule {
    id     = "delete-old-emails"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "incoming_emails" {
  bucket = aws_s3_bucket.incoming_emails.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket policy - allow SES to put objects
resource "aws_s3_bucket_policy" "incoming_emails" {
  bucket = aws_s3_bucket.incoming_emails.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPuts"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.incoming_emails.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution" {
  name = "ses-email-forwarder-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "SES Email Forwarder Lambda Role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_execution" {
  name = "ses-email-forwarder-lambda-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3GetObject"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.incoming_emails.arn}/*"
      },
      {
        Sid    = "SESSendRawEmail"
        Effect = "Allow"
        Action = [
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerGetSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = local.secret_arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/ses-email-forwarder"
  retention_in_days = 14

  tags = {
    Name        = "SES Email Forwarder Lambda Logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Lambda Function
resource "aws_lambda_function" "ses_email_forwarder" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ses-email-forwarder"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  architectures    = ["arm64"]
  layers           = ["arn:aws:lambda:us-east-1:943013980633:layer:SentryPythonServerlessSDK:188"]

  environment {
    variables = {
      EMAIL_BUCKET         = aws_s3_bucket.incoming_emails.id
      AIRTABLE_SECRET_NAME = var.airtable_secret_name
      FORWARD_FROM_EMAIL   = var.forward_from_email
      AWS_SES_REGION       = "us-east-1"
      ENVIRONMENT          = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_execution
  ]

  tags = {
    Name        = "SES Email Forwarder"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Lambda Permission - allow SES to invoke
resource "aws_lambda_permission" "ses_invoke" {
  statement_id   = "AllowSESInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.ses_email_forwarder.function_name
  principal      = "ses.amazonaws.com"
  source_account = var.account_id
}

# SES Domain Identity
resource "aws_ses_domain_identity" "coders" {
  domain = var.domain
}

# SES Domain DKIM
resource "aws_ses_domain_dkim" "coders" {
  domain = aws_ses_domain_identity.coders.domain
}

# SES Receipt Rule Set
resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "coders-email-forwarding"
}

# SES Receipt Rule
resource "aws_ses_receipt_rule" "forward" {
  name          = "forward-to-lambda"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = [var.domain]
  enabled       = true
  scan_enabled  = true

  # Action 1: Store email in S3
  s3_action {
    bucket_name = aws_s3_bucket.incoming_emails.id
    position    = 1
  }

  # Action 2: Invoke Lambda
  lambda_action {
    function_arn    = aws_lambda_function.ses_email_forwarder.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_s3_bucket_policy.incoming_emails,
    aws_lambda_permission.ses_invoke
  ]
}

# Activate the receipt rule set
resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}
