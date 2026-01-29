# ============================================================================
# SNS Topics for Bounce and Complaint Notifications
# ============================================================================

resource "aws_sns_topic" "ses_bounces" {
  name = "ses-email-bounces"

  tags = {
    Name        = "SES Email Bounces"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic" "ses_complaints" {
  name = "ses-email-complaints"

  tags = {
    Name        = "SES Email Complaints"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# Lambda Function for Bounce and Complaint Handling
# ============================================================================

resource "aws_lambda_function" "bounce_handler" {
  filename         = data.archive_file.bounce_lambda_zip.output_path
  function_name    = "ses-bounce-handler"
  role             = aws_iam_role.bounce_lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.bounce_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  architectures    = ["arm64"]

  # Sentry layer for error monitoring
  layers = ["arn:aws:lambda:us-east-1:943013980633:layer:SentryPythonServerlessSDK:188"]

  environment {
    variables = {
      AIRTABLE_SECRET_NAME = var.airtable_secret_name
      ENVIRONMENT          = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.bounce_lambda,
    aws_iam_role_policy_attachment.bounce_lambda_basic_execution,
    aws_iam_role_policy.bounce_lambda_execution
  ]

  tags = {
    Name        = "SES Bounce Handler"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "bounce_lambda" {
  name              = "/aws/lambda/ses-bounce-handler"
  retention_in_days = 14

  tags = {
    Name        = "SES Bounce Handler Lambda Logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# IAM Role and Policies for Bounce Handler Lambda
# ============================================================================

resource "aws_iam_role" "bounce_lambda_execution" {
  name = "ses-bounce-handler-lambda-role"

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
    Name        = "SES Bounce Handler Lambda Role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "bounce_lambda_execution" {
  name = "ses-bounce-handler-lambda-policy"
  role = aws_iam_role.bounce_lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

resource "aws_iam_role_policy_attachment" "bounce_lambda_basic_execution" {
  role       = aws_iam_role.bounce_lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# SNS Subscriptions - Connect SNS Topics to Lambda
# ============================================================================

resource "aws_sns_topic_subscription" "bounces_to_lambda" {
  topic_arn = aws_sns_topic.ses_bounces.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.bounce_handler.arn
}

resource "aws_sns_topic_subscription" "complaints_to_lambda" {
  topic_arn = aws_sns_topic.ses_complaints.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.bounce_handler.arn
}

# ============================================================================
# Lambda Permissions - Allow SNS to Invoke Lambda
# ============================================================================

resource "aws_lambda_permission" "sns_bounces_invoke" {
  statement_id  = "AllowSNSBouncesInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bounce_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ses_bounces.arn
}

resource "aws_lambda_permission" "sns_complaints_invoke" {
  statement_id  = "AllowSNSComplaintsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bounce_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ses_complaints.arn
}

# ============================================================================
# SES Configuration Set - Routes Bounce/Complaint Events to SNS
# ============================================================================

resource "aws_ses_configuration_set" "main" {
  name = "coders-email-forwarding-config"

  reputation_metrics_enabled = true
}

resource "aws_ses_event_destination" "bounces" {
  name                   = "bounce-notifications"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["bounce"]

  sns_destination {
    topic_arn = aws_sns_topic.ses_bounces.arn
  }
}

resource "aws_ses_event_destination" "complaints" {
  name                   = "complaint-notifications"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["complaint"]

  sns_destination {
    topic_arn = aws_sns_topic.ses_complaints.arn
  }
}

# ============================================================================
# Data Source - Package Bounce Handler Lambda Code
# ============================================================================

data "archive_file" "bounce_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/ses_bounce_handler"
  output_path = "${path.module}/bounce_handler.zip"

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
