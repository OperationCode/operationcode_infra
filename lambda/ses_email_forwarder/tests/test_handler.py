import json
import os
import sys
import unittest
from unittest.mock import Mock, patch, MagicMock
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import base64

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import handler


class TestLambdaHandler(unittest.TestCase):
    """Test suite for SES email forwarder Lambda function."""

    def setUp(self):
        """Set up test fixtures."""
        # Set required environment variables
        os.environ['EMAIL_BUCKET'] = 'test-bucket'
        os.environ['AIRTABLE_SECRET_NAME'] = 'test-secret'
        os.environ['FORWARD_FROM_EMAIL'] = 'noreply@coders.operationcode.org'
        os.environ['AWS_SES_REGION'] = 'us-east-1'
        os.environ['ENVIRONMENT'] = 'test'

        # Reset caches
        handler._secrets_cache = None
        handler._config_cache = None
        handler._s3_client = None
        handler._ses_client = None
        handler._secrets_client = None

        # Load sample SES event
        fixture_path = os.path.join(os.path.dirname(__file__), 'fixtures', 'sample_ses_event.json')
        with open(fixture_path, 'r') as f:
            self.sample_event = json.load(f)

    def tearDown(self):
        """Clean up after tests."""
        handler._secrets_cache = None
        handler._config_cache = None
        handler._s3_client = None
        handler._ses_client = None
        handler._secrets_client = None

    def test_get_airtable_credentials_caching(self):
        """Test that credentials are cached after first retrieval."""
        mock_response = {
            'SecretString': json.dumps({
                'airtable_api_key': 'test_key',
                'airtable_base_id': 'test_base',
                'airtable_table_name': 'Email Aliases',
                'sentry_dsn': 'https://test@test.ingest.sentry.io/test'
            })
        }

        mock_secrets_client = Mock()
        mock_secrets_client.get_secret_value.return_value = mock_response

        with patch.object(handler, 'get_secrets_client', return_value=mock_secrets_client):
            # First call should hit Secrets Manager
            creds1 = handler.get_airtable_credentials()
            self.assertEqual(mock_secrets_client.get_secret_value.call_count, 1)

            # Second call should use cache
            creds2 = handler.get_airtable_credentials()
            self.assertEqual(mock_secrets_client.get_secret_value.call_count, 1)  # Still 1, not 2

            # Verify credentials
            self.assertEqual(creds1['airtable_api_key'], 'test_key')
            self.assertEqual(creds1, creds2)

    @patch('handler.urllib.request.urlopen')
    def test_lookup_alias_active(self, mock_urlopen):
        """Test looking up an active alias in Airtable."""
        # Mock Secrets Manager
        with patch.object(handler, 'get_airtable_credentials', return_value={
            'airtable_api_key': 'test_key',
            'airtable_base_id': 'test_base',
            'airtable_table_name': 'Email Aliases'
        }):
            # Mock Airtable API response
            mock_response = MagicMock()
            mock_response.read.return_value = json.dumps({
                'records': [{
                    'id': 'rec123',
                    'fields': {
                        'Alias': 'testuser',
                        'Email': 'test@example.com',
                        'Name': 'Test User',
                        'Status': 'active'
                    }
                }]
            }).encode()
            mock_response.__enter__.return_value = mock_response
            mock_urlopen.return_value = mock_response

            result = handler.lookup_alias_in_airtable('testuser')

            self.assertIsNotNone(result)
            self.assertEqual(result['Email'], 'test@example.com')
            self.assertEqual(result['Name'], 'Test User')

    @patch('handler.urllib.request.urlopen')
    def test_lookup_alias_not_found(self, mock_urlopen):
        """Test looking up a non-existent alias."""
        with patch.object(handler, 'get_airtable_credentials', return_value={
            'airtable_api_key': 'test_key',
            'airtable_base_id': 'test_base',
            'airtable_table_name': 'Email Aliases'
        }):
            # Mock empty Airtable response
            mock_response = MagicMock()
            mock_response.read.return_value = json.dumps({'records': []}).encode()
            mock_response.__enter__.return_value = mock_response
            mock_urlopen.return_value = mock_response

            result = handler.lookup_alias_in_airtable('nonexistent')

            self.assertIsNone(result)

    def test_get_email_from_s3(self):
        """Test retrieving email from S3."""
        mock_email_content = b"From: sender@example.com\nTo: test@coders.operationcode.org\n\nTest body"

        mock_response = {
            'Body': MagicMock()
        }
        mock_response['Body'].read.return_value = mock_email_content

        mock_s3_client = Mock()
        mock_s3_client.get_object.return_value = mock_response

        with patch.object(handler, 'get_s3_client', return_value=mock_s3_client):
            result = handler.get_email_from_s3('test-message-id')

            self.assertEqual(result, mock_email_content)
            mock_s3_client.get_object.assert_called_once_with(
                Bucket='test-bucket',
                Key='test-message-id'
            )

    def test_forward_email_simple(self):
        """Test forwarding a simple text email."""
        # Create a simple email
        original_msg = MIMEText('Test email body', 'plain')
        original_msg['From'] = 'sender@example.com'
        original_msg['To'] = 'test@coders.operationcode.org'
        original_msg['Subject'] = 'Test Subject'
        raw_email = original_msg.as_bytes()

        mock_ses_response = {'MessageId': 'ses-msg-123'}
        mock_ses_client = Mock()
        mock_ses_client.send_raw_email.return_value = mock_ses_response

        with patch.object(handler, 'get_ses_client', return_value=mock_ses_client):
            result = handler.forward_email(raw_email, 'recipient@example.com', 'test@coders.operationcode.org')

            self.assertEqual(result['MessageId'], 'ses-msg-123')
            mock_ses_client.send_raw_email.assert_called_once()

            # Check the call arguments
            call_args = mock_ses_client.send_raw_email.call_args
            self.assertEqual(call_args[1]['Source'], 'noreply@coders.operationcode.org')
            self.assertEqual(call_args[1]['Destinations'], ['recipient@example.com'])

    def test_forward_email_with_attachment(self):
        """Test forwarding an email with attachment."""
        # Create email with attachment
        msg = MIMEMultipart()
        msg['From'] = 'sender@example.com'
        msg['To'] = 'test@coders.operationcode.org'
        msg['Subject'] = 'Test with Attachment'

        # Add body
        msg.attach(MIMEText('Email body', 'plain'))

        # Add attachment
        attachment = MIMEText('attachment content', 'plain')
        attachment.add_header('Content-Disposition', 'attachment', filename='test.txt')
        msg.attach(attachment)

        raw_email = msg.as_bytes()

        mock_ses_response = {'MessageId': 'ses-msg-456'}
        mock_ses_client = Mock()
        mock_ses_client.send_raw_email.return_value = mock_ses_response

        with patch.object(handler, 'get_ses_client', return_value=mock_ses_client):
            result = handler.forward_email(raw_email, 'recipient@example.com', 'test@coders.operationcode.org')

            self.assertEqual(result['MessageId'], 'ses-msg-456')

    @patch('handler.init_sentry')
    @patch('handler.get_email_from_s3')
    @patch('handler.forward_email')
    @patch('handler.lookup_alias_in_airtable')
    def test_lambda_handler_success(self, mock_lookup, mock_forward, mock_get_email, mock_sentry):
        """Test successful Lambda handler execution."""
        # Mock Airtable lookup
        mock_lookup.return_value = {
            'Email': 'recipient@example.com',
            'Name': 'Test User',
            'Status': 'active'
        }

        # Mock S3 email retrieval
        mock_get_email.return_value = b"From: sender@example.com\nSubject: Test\n\nBody"

        # Mock SES send
        mock_forward.return_value = {'MessageId': 'test-msg-id'}

        result = handler.lambda_handler(self.sample_event, None)

        self.assertEqual(result['statusCode'], 200)
        self.assertEqual(result['body'], 'Processed')
        mock_lookup.assert_called_once_with('testuser')
        mock_get_email.assert_called_once()
        mock_forward.assert_called_once()

    @patch('handler.init_sentry')
    @patch('handler.lookup_alias_in_airtable')
    def test_lambda_handler_inactive_alias(self, mock_lookup, mock_sentry):
        """Test Lambda handler with inactive alias (should not forward)."""
        # Mock Airtable lookup returning None (inactive or not found)
        mock_lookup.return_value = None

        result = handler.lambda_handler(self.sample_event, None)

        self.assertEqual(result['statusCode'], 200)
        self.assertEqual(result['body'], 'Processed')
        mock_lookup.assert_called_once_with('testuser')

    @patch('handler.init_sentry')
    @patch('handler.get_email_from_s3')
    @patch('handler.lookup_alias_in_airtable')
    def test_lambda_handler_missing_personal_email(self, mock_lookup, mock_get_email, mock_sentry):
        """Test Lambda handler when Email is missing from mapping."""
        # Mock Airtable lookup with missing Email
        mock_lookup.return_value = {
            'Name': 'Test User',
            'Status': 'active'
            # Email is missing
        }

        result = handler.lambda_handler(self.sample_event, None)

        self.assertEqual(result['statusCode'], 200)
        self.assertEqual(result['body'], 'Processed')
        # Should not attempt to get email from S3
        mock_get_email.assert_not_called()

    @patch('handler.init_sentry')
    @patch('handler.get_email_from_s3')
    @patch('handler.forward_email')
    @patch('handler.lookup_alias_in_airtable')
    @patch('handler.sentry_sdk')
    def test_lambda_handler_forward_error(self, mock_sentry_sdk, mock_lookup, mock_forward, mock_get_email, mock_sentry):
        """Test Lambda handler error handling when forwarding fails."""
        mock_lookup.return_value = {
            'Email': 'recipient@example.com',
            'Name': 'Test User',
            'Status': 'active'
        }

        mock_get_email.return_value = b"test email"
        mock_forward.side_effect = Exception("SES error")

        with self.assertRaises(Exception):
            handler.lambda_handler(self.sample_event, None)

        # Verify Sentry was called to capture the exception
        mock_sentry_sdk.capture_exception.assert_called()

    def test_lambda_handler_invalid_recipient_format(self):
        """Test Lambda handler with invalid recipient format."""
        invalid_event = {
            'Records': [{
                'eventSource': 'aws:ses',
                'ses': {
                    'mail': {
                        'messageId': 'test-msg',
                        'source': 'sender@example.com',
                        'destination': ['invalid-no-at-sign']
                    }
                }
            }]
        }

        with patch('handler.init_sentry'):
            result = handler.lambda_handler(invalid_event, None)

            self.assertEqual(result['statusCode'], 200)
            self.assertEqual(result['body'], 'Processed')


if __name__ == '__main__':
    unittest.main()
