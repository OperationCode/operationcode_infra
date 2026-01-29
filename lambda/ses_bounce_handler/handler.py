import boto3
import os
import json
import urllib.request
import urllib.error
import urllib.parse
import sentry_sdk
from sentry_sdk.integrations.aws_lambda import AwsLambdaIntegration

# Cache for secrets and config
_secrets_cache = None
_config_cache = None

# AWS clients (initialized lazily)
_secrets_client = None


def get_config():
    """Get configuration from environment variables with caching."""
    global _config_cache
    if _config_cache is None:
        _config_cache = {
            'airtable_secret_name': os.environ.get('AIRTABLE_SECRET_NAME', ''),
            'environment': os.environ.get('ENVIRONMENT', 'production')
        }
    return _config_cache


def get_secrets_client():
    """Get Secrets Manager client with lazy initialization."""
    global _secrets_client
    if _secrets_client is None:
        _secrets_client = boto3.client('secretsmanager', region_name='us-east-2')
    return _secrets_client


def get_airtable_credentials():
    """
    Fetch Airtable credentials from Secrets Manager with caching.

    Returns:
        dict: Contains airtable_api_key, airtable_base_id, airtable_table_name, sentry_dsn
    """
    global _secrets_cache
    if _secrets_cache is None:
        config = get_config()
        secret_name = config['airtable_secret_name']
        try:
            secrets_client = get_secrets_client()
            response = secrets_client.get_secret_value(SecretId=secret_name)
            _secrets_cache = json.loads(response['SecretString'])
            print(f"Successfully retrieved secrets from {secret_name}")
        except Exception as e:
            print(f"Error retrieving secrets from {secret_name}: {str(e)}")
            raise
    return _secrets_cache


def init_sentry():
    """Initialize Sentry with DSN from Secrets Manager."""
    try:
        config = get_config()
        credentials = get_airtable_credentials()
        sentry_dsn = credentials.get('sentry_dsn')
        if sentry_dsn:
            sentry_sdk.init(
                dsn=sentry_dsn,
                integrations=[AwsLambdaIntegration()],
                environment=config['environment'],
                traces_sample_rate=0.1
            )
            print("Sentry initialized successfully")
        else:
            print("No Sentry DSN found in secrets")
    except Exception as e:
        print(f"Error initializing Sentry: {str(e)}")


def find_airtable_record_by_email(email):
    """
    Query Airtable to find record with matching Email field.

    Args:
        email: Email address to search for

    Returns:
        dict with 'id' and 'fields', or None if not found
    """
    credentials = get_airtable_credentials()
    base_id = credentials['airtable_base_id']
    table_name = credentials['airtable_table_name']
    api_key = credentials['airtable_api_key']

    # URL encode the filter formula
    filter_formula = f"{{Email}}='{email}'"
    encoded_formula = urllib.parse.quote(filter_formula)
    url = f"https://api.airtable.com/v0/{base_id}/{urllib.parse.quote(table_name)}?filterByFormula={encoded_formula}"

    try:
        # Create request with authorization header
        req = urllib.request.Request(url)
        req.add_header('Authorization', f'Bearer {api_key}')

        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            records = data.get('records', [])

            if records:
                print(f"Found Airtable record for {email}: {records[0]['id']}")
                return records[0]
            else:
                print(f"No Airtable record found for {email}")
                return None

    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"HTTP error querying Airtable for {email}: {e.code} - {error_body}")
        raise
    except Exception as e:
        print(f"Error querying Airtable for {email}: {str(e)}")
        raise


def update_airtable_record(record_id, updates):
    """
    Update Airtable record using PATCH API.

    Args:
        record_id: Airtable record ID (starts with 'rec')
        updates: Dict of field names to new values
    """
    credentials = get_airtable_credentials()
    base_id = credentials['airtable_base_id']
    table_name = credentials['airtable_table_name']
    api_key = credentials['airtable_api_key']

    url = f"https://api.airtable.com/v0/{base_id}/{urllib.parse.quote(table_name)}/{record_id}"

    # Prepare the request body
    body = {
        'fields': updates
    }
    json_data = json.dumps(body).encode('utf-8')

    try:
        # Create PATCH request with authorization header
        req = urllib.request.Request(url, data=json_data, method='PATCH')
        req.add_header('Authorization', f'Bearer {api_key}')
        req.add_header('Content-Type', 'application/json')

        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            print(f"Successfully updated Airtable record {record_id}")
            return result

    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"HTTP error updating Airtable record {record_id}: {e.code} - {error_body}")
        raise
    except Exception as e:
        print(f"Error updating Airtable record {record_id}: {str(e)}")
        raise


def handle_bounce(message):
    """
    Process SES bounce notification.

    SNS message structure:
    {
      "notificationType": "Bounce",
      "bounce": {
        "bounceType": "Permanent|Transient|Undetermined",
        "bounceSubType": "General|NoEmail|MailboxFull|...",
        "bouncedRecipients": [
          {"emailAddress": "user@example.com", "status": "5.1.1", ...}
        ],
        "timestamp": "2026-01-28T12:00:00.000Z"
      },
      "mail": {
        "messageId": "...",
        "source": "noreply@coders.operationcode.org",
        "destination": ["user@example.com"]
      }
    }
    """
    bounce = message['bounce']
    bounce_type = bounce['bounceType']
    bounce_timestamp = bounce['timestamp']

    for recipient in bounce['bouncedRecipients']:
        email_address = recipient['emailAddress']

        # Find Airtable record
        record = find_airtable_record_by_email(email_address)

        if not record:
            print(f"No Airtable record found for {email_address}")
            continue

        # Get current bounce_count (default to 0 if field doesn't exist)
        current_fields = record.get('fields', {})
        current_count = current_fields.get('bounce_count', 0)

        # Prepare updates
        updates = {
            'bounce_count': current_count + 1,
            'last_bounce_date': bounce_timestamp[:10],  # YYYY-MM-DD
            'last_bounce_type': bounce_type
        }

        # Permanent bounces disable the alias immediately
        if bounce_type == "Permanent":
            updates['Status'] = "bouncing"
            print(f"Permanent bounce for {email_address} - disabling alias")
        else:
            print(f"Transient bounce for {email_address} - incrementing counter")

        # Update Airtable
        update_airtable_record(record['id'], updates)


def handle_complaint(message):
    """
    Process SES complaint notification.

    SNS message structure:
    {
      "notificationType": "Complaint",
      "complaint": {
        "complainedRecipients": [
          {"emailAddress": "user@example.com"}
        ],
        "timestamp": "2026-01-28T12:00:00.000Z",
        "complaintFeedbackType": "abuse|auth-failure|fraud|..."
      },
      "mail": {...}
    }
    """
    complaint = message['complaint']
    complaint_timestamp = complaint['timestamp']

    for recipient in complaint['complainedRecipients']:
        email_address = recipient['emailAddress']

        # Find Airtable record
        record = find_airtable_record_by_email(email_address)

        if not record:
            print(f"No Airtable record found for {email_address}")
            continue

        # Get current count
        current_fields = record.get('fields', {})
        current_count = current_fields.get('complaint_count', 0)

        # Prepare updates - complaints disable immediately
        updates = {
            'complaint_count': current_count + 1,
            'last_complaint_date': complaint_timestamp[:10],
            'Status': "bouncing"  # Disable on first complaint (reputation!)
        }

        print(f"Complaint received for {email_address} - disabling alias")

        # Update Airtable
        update_airtable_record(record['id'], updates)


def lambda_handler(event, context):
    """
    Main Lambda handler for SNS notifications from SES.

    Event structure (SNS wrapper around SES notification):
    {
      "Records": [
        {
          "EventSource": "aws:sns",
          "Sns": {
            "Message": "{...SES notification JSON...}",
            "Subject": "Amazon SES Bounce Notification",
            "TopicArn": "arn:aws:sns:us-east-1:...:ses-email-bounces"
          }
        }
      ]
    }
    """
    # Initialize Sentry on first invocation
    init_sentry()

    try:
        for record in event['Records']:
            # Parse SNS message
            sns_message = record['Sns']['Message']
            message = json.loads(sns_message)

            notification_type = message.get('notificationType')

            print(f"Processing {notification_type} notification")

            if notification_type == 'Bounce':
                handle_bounce(message)
            elif notification_type == 'Complaint':
                handle_complaint(message)
            else:
                print(f"Unknown notification type: {notification_type}")

        return {'statusCode': 200, 'body': 'Success'}

    except Exception as e:
        print(f"Error processing notification: {str(e)}")
        sentry_sdk.capture_exception(e)
        raise  # Re-raise to trigger Lambda retry
