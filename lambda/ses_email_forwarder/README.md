# SES Email Forwarder Lambda Function

This Lambda function forwards emails received by AWS SES to personal email addresses based on alias mappings stored in Airtable.

## Overview

When a donor with recurring donations receives a custom email alias (e.g., `john@coders.operationcode.org`), this Lambda function:
1. Receives the email via SES
2. Checks Airtable for the alias mapping
3. Validates the donor's status is "active"
4. Forwards the email to the donor's personal email address

## Environment Variables

- `EMAIL_BUCKET` - S3 bucket name where SES stores incoming emails
- `AIRTABLE_SECRET_NAME` - Name of the secret in AWS Secrets Manager containing Airtable credentials
- `FORWARD_FROM_EMAIL` - Email address to use as the "From" address (e.g., noreply@coders.operationcode.org)
- `AWS_SES_REGION` - AWS region for SES (us-east-1)
- `ENVIRONMENT` - Environment name for Sentry (prod/staging)

## Secrets Manager Schema

The secret referenced by `AIRTABLE_SECRET_NAME` must contain:
```json
{
  "airtable_api_key": "patXXXXXXXXXXXXXX",
  "airtable_base_id": "appXXXXXXXXXXXXXX",
  "airtable_table_name": "Email Aliases",
  "sentry_dsn": "https://xxxxx@oxxxxx.ingest.sentry.io/xxxxx"
}
```

## Local Testing

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install pytest moto urllib3

# Run tests
pytest tests/ -v
```

## Architecture

- **Region**: us-east-1 (required for SES email receiving)
- **Runtime**: Python 3.12
- **Memory**: 256 MB
- **Timeout**: 30 seconds
- **Architecture**: ARM64 (Graviton)

## Email Flow

1. Email sent to `alias@coders.operationcode.org`
2. SES receives email and stores it in S3
3. SES invokes Lambda function
4. Lambda:
   - Retrieves email from S3
   - Queries Airtable for alias mapping
   - Validates donor status is "active"
   - Rewrites headers (From, Reply-To)
   - Sends email via SES to personal email
5. Original sender receives replies via Reply-To header

## Error Handling

Errors are logged to:
- CloudWatch Logs: `/aws/lambda/ses-email-forwarder`
- Sentry: For alerting and monitoring
