import boto3
import email
import os
import json
import urllib.request
import urllib.error
import urllib.parse
from email import policy
from email.parser import BytesParser
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import sentry_sdk
from sentry_sdk.integrations.aws_lambda import AwsLambdaIntegration

# Cache for secrets and config
_secrets_cache = None
_config_cache = None

# AWS clients (initialized lazily)
_s3_client = None
_ses_client = None
_secrets_client = None


def get_config():
    """Get configuration from environment variables with caching."""
    global _config_cache
    if _config_cache is None:
        _config_cache = {
            'email_bucket': os.environ.get('EMAIL_BUCKET', ''),
            'airtable_secret_name': os.environ.get('AIRTABLE_SECRET_NAME', ''),
            'forward_from_email': os.environ.get('FORWARD_FROM_EMAIL', ''),
            'aws_ses_region': os.environ.get('AWS_SES_REGION', 'us-east-1'),
            'environment': os.environ.get('ENVIRONMENT', 'production')
        }
    return _config_cache


def get_s3_client():
    """Get S3 client with lazy initialization."""
    global _s3_client
    if _s3_client is None:
        _s3_client = boto3.client('s3')
    return _s3_client


def get_ses_client():
    """Get SES client with lazy initialization."""
    global _ses_client
    if _ses_client is None:
        config = get_config()
        _ses_client = boto3.client('ses', region_name=config['aws_ses_region'])
    return _ses_client


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


# Initialize Sentry (deferred until first invocation to get DSN from Secrets Manager)
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
                traces_sample_rate=0.1,  # 10% transaction sampling
                environment=config['environment']
            )
            print("Sentry initialized successfully")
        else:
            print("Warning: No sentry_dsn found in secrets")
    except Exception as e:
        print(f"Warning: Failed to initialize Sentry: {str(e)}")


def lookup_alias_in_airtable(alias: str) -> dict | None:
    """
    Query Airtable to find the mapping for a given alias.
    Returns the record if found and active, None otherwise.

    Args:
        alias: The email alias (local part before @)

    Returns:
        dict or None: The Airtable record fields if found and active
    """
    credentials = get_airtable_credentials()
    airtable_api_key = credentials['airtable_api_key']
    airtable_base_id = credentials['airtable_base_id']
    airtable_table_name = credentials['airtable_table_name']

    url = f"https://api.airtable.com/v0/{airtable_base_id}/{urllib.parse.quote(airtable_table_name)}"

    # Filter for exact alias match and active status
    # Note: Airtable field names are case-sensitive
    params = urllib.parse.urlencode({
        'filterByFormula': f"AND({{Alias}} = '{alias}', {{Status}} = 'active')",
        'maxRecords': 1
    })

    full_url = f"{url}?{params}"

    req = urllib.request.Request(
        full_url,
        headers={
            'Authorization': f'Bearer {airtable_api_key}',
            'Content-Type': 'application/json'
        }
    )

    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            records = data.get('records', [])
            if records:
                print(f"Found active alias mapping for: {alias}")
                return records[0]['fields']
            print(f"No active alias mapping found for: {alias}")
            return None
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"Airtable API error: {e.code} - {error_body}")
        sentry_sdk.capture_exception(e)
        return None
    except Exception as e:
        print(f"Error querying Airtable: {str(e)}")
        sentry_sdk.capture_exception(e)
        return None


def get_email_from_s3(message_id: str) -> bytes:
    """
    Retrieve the raw email from S3.

    Args:
        message_id: The SES message ID (used as S3 key)

    Returns:
        bytes: The raw email content
    """
    try:
        config = get_config()
        s3_client = get_s3_client()
        response = s3_client.get_object(
            Bucket=config['email_bucket'],
            Key=message_id
        )
        return response['Body'].read()
    except Exception as e:
        print(f"Error retrieving email from S3: {str(e)}")
        sentry_sdk.capture_exception(e)
        raise


def forward_email(raw_email: bytes, forward_to: str, original_recipient: str) -> dict:
    """
    Parse the original email and forward it to the destination address.
    Rewrites headers to comply with SES requirements while preserving
    the original sender information.

    Args:
        raw_email: The raw email bytes from S3
        forward_to: The destination email address
        original_recipient: The original recipient address (alias@coders.operationcode.org)

    Returns:
        dict: SES send_raw_email response
    """
    config = get_config()

    # Parse the original email
    original_msg = BytesParser(policy=policy.default).parsebytes(raw_email)

    # Extract original headers
    original_from = original_msg['From']
    original_subject = original_msg['Subject'] or '(no subject)'
    original_to = original_msg['To']
    original_date = original_msg['Date']
    original_message_id = original_msg['Message-ID']

    # Create new message
    new_msg = MIMEMultipart('mixed')

    # Set headers for forwarded message
    # SES requires From to be a verified identity
    new_msg['From'] = config['forward_from_email']
    new_msg['To'] = forward_to
    new_msg['Subject'] = original_subject
    new_msg['Reply-To'] = original_from  # Replies go to original sender

    # Add custom headers to preserve original info
    new_msg['X-Original-From'] = original_from
    new_msg['X-Original-To'] = original_recipient
    new_msg['X-Forwarded-For'] = original_recipient

    # Handle multipart messages (with attachments) vs simple messages
    if original_msg.is_multipart():
        # Copy all parts from original message
        for part in original_msg.walk():
            content_type = part.get_content_type()
            content_disposition = str(part.get('Content-Disposition', ''))

            if content_type == 'multipart/mixed' or content_type == 'multipart/alternative':
                continue

            if 'attachment' in content_disposition:
                # Handle attachments
                new_part = MIMEBase(*content_type.split('/'))
                new_part.set_payload(part.get_payload(decode=True))
                encoders.encode_base64(new_part)
                new_part.add_header(
                    'Content-Disposition',
                    'attachment',
                    filename=part.get_filename() or 'attachment'
                )
                new_msg.attach(new_part)
            else:
                # Handle body parts
                payload = part.get_payload(decode=True)
                if payload:
                    if content_type == 'text/plain':
                        new_msg.attach(MIMEText(payload.decode('utf-8', errors='replace'), 'plain'))
                    elif content_type == 'text/html':
                        new_msg.attach(MIMEText(payload.decode('utf-8', errors='replace'), 'html'))
    else:
        # Simple message without attachments
        payload = original_msg.get_payload(decode=True)
        if payload:
            content_type = original_msg.get_content_type()
            if content_type == 'text/html':
                new_msg.attach(MIMEText(payload.decode('utf-8', errors='replace'), 'html'))
            else:
                new_msg.attach(MIMEText(payload.decode('utf-8', errors='replace'), 'plain'))

    # Send via SES
    try:
        ses_client = get_ses_client()
        response = ses_client.send_raw_email(
            Source=config['forward_from_email'],
            Destinations=[forward_to],
            RawMessage={'Data': new_msg.as_bytes()}
        )
        return response
    except Exception as e:
        print(f"Error sending email via SES: {str(e)}")
        sentry_sdk.capture_exception(e)
        raise


def lambda_handler(event, context):
    """
    Lambda handler for SES incoming email events.

    Event structure:
    {
        "Records": [{
            "eventSource": "aws:ses",
            "eventVersion": "1.0",
            "ses": {
                "mail": {
                    "messageId": "...",
                    "source": "sender@example.com",
                    "destination": ["recipient@coders.operationcode.org"]
                },
                "receipt": {
                    "recipients": ["recipient@coders.operationcode.org"],
                    ...
                }
            }
        }]
    }

    Args:
        event: SES event containing email details
        context: Lambda context object

    Returns:
        dict: Response with statusCode and body
    """
    # Initialize Sentry on first invocation
    if _secrets_cache is None:
        init_sentry()

    print(f"Received event: {json.dumps(event)}")

    for record in event.get('Records', []):
        ses_data = record.get('ses', {})
        mail_data = ses_data.get('mail', {})

        message_id = mail_data.get('messageId')
        recipients = mail_data.get('destination', [])
        source = mail_data.get('source', 'unknown')

        print(f"Processing message {message_id} from {source} to {recipients}")

        for recipient in recipients:
            # Extract alias from recipient address
            # e.g., "john482@coders.operationcode.org" -> "john482"
            if '@' not in recipient:
                print(f"Invalid recipient format: {recipient}")
                continue

            alias = recipient.split('@')[0].lower()
            print(f"Looking up alias: {alias}")

            # Query Airtable for the mapping
            mapping = lookup_alias_in_airtable(alias)

            if not mapping:
                print(f"No active mapping found for alias: {alias}")
                # Silently drop emails to unknown aliases
                continue

            forward_to = mapping.get('Email')
            donor_name = mapping.get('Name', 'Member')

            if not forward_to:
                print(f"No Email field in mapping for alias: {alias}")
                continue

            print(f"Forwarding to: {forward_to} ({donor_name})")

            try:
                # Get the raw email from S3
                raw_email = get_email_from_s3(message_id)

                # Forward it
                response = forward_email(raw_email, forward_to, recipient)
                print(f"Successfully forwarded. SES MessageId: {response.get('MessageId')}")

            except Exception as e:
                error_msg = f"Error forwarding email for alias {alias}: {str(e)}"
                print(error_msg)
                sentry_sdk.capture_exception(e)
                raise

    return {
        'statusCode': 200,
        'body': 'Processed'
    }
