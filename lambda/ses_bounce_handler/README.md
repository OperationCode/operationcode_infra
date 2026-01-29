# SES Bounce and Complaint Handler

Lambda function that processes SES bounce and complaint notifications to maintain email sender reputation and automatically disable problematic email aliases.

## Overview

This Lambda function:
- Receives bounce and complaint notifications from SES via SNS topics
- Queries Airtable to find the affected email alias
- Updates bounce/complaint counts and timestamps
- Automatically disables aliases for permanent bounces and spam complaints

## Architecture

```
SES Email → Bounce/Complaint → SNS Topic → Lambda → Airtable Update
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AIRTABLE_SECRET_NAME` | Name of secret in AWS Secrets Manager | `operation-code-automation` |
| `ENVIRONMENT` | Environment name for Sentry tagging | `prod` |

## Secrets Manager

The function expects the following fields in the secret:
- `airtable_api_key` - Airtable API key
- `airtable_base_id` - Airtable base ID (e.g., `appXXXXXXXXXXXXXX`)
- `airtable_table_name` - Table name (e.g., `Email Aliases`)
- `sentry_dsn` - Sentry DSN for error monitoring (optional)

## Bounce Handling Logic

| Bounce Type | Action | Rationale |
|-------------|--------|-----------|
| **Permanent** | Set `Status = "bouncing"` immediately | Invalid email - stop forwarding |
| **Transient** | Increment `bounce_count`, keep active | Temporary issue - allow retry |

## Complaint Handling Logic

All complaints immediately set `Status = "bouncing"` to protect sender reputation.

## Airtable Fields Updated

- `bounce_count` (Number) - Total bounce events
- `last_bounce_date` (Date) - Most recent bounce
- `last_bounce_type` (Single Select) - Permanent, Transient, or Undetermined
- `complaint_count` (Number) - Total complaint events
- `last_complaint_date` (Date) - Most recent complaint
- `Status` (Single Select) - Set to "bouncing" for permanent bounces and complaints

## Testing

Run unit tests:
```bash
cd lambda/ses_bounce_handler
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install pytest moto urllib3
pytest tests/ -v
```

Test with SES Mailbox Simulator:
- `bounce@simulator.amazonses.com` - Permanent bounce
- `ooto@simulator.amazonses.com` - Transient bounce
- `complaint@simulator.amazonses.com` - Spam complaint

## Monitoring

CloudWatch Logs: `/aws/lambda/ses-bounce-handler`

Sentry errors are automatically captured and reported.

## Dependencies

- boto3 - AWS SDK
- sentry-sdk - Error monitoring
