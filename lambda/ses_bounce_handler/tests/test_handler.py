import unittest
from unittest.mock import patch, MagicMock
import json
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import handler


class TestBounceHandler(unittest.TestCase):

    def setUp(self):
        """Reset global caches before each test"""
        handler._config_cache = None
        handler._secrets_cache = None
        handler._secrets_client = None

    @patch.dict(os.environ, {
        'AIRTABLE_SECRET_NAME': 'test-secret',
        'ENVIRONMENT': 'test'
    })
    def test_get_config(self):
        """Test configuration loading from environment variables"""
        config = handler.get_config()
        self.assertEqual(config['airtable_secret_name'], 'test-secret')
        self.assertEqual(config['environment'], 'test')

    @patch('handler.urllib.request.urlopen')
    @patch('handler.get_airtable_credentials')
    def test_find_record_by_email_found(self, mock_creds, mock_urlopen):
        """Test finding Airtable record by email address"""
        # Mock credentials
        mock_creds.return_value = {
            'airtable_api_key': 'test_key',
            'airtable_base_id': 'appTEST123',
            'airtable_table_name': 'Email Aliases'
        }

        # Mock Airtable API response
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps({
            'records': [
                {
                    'id': 'recABC123',
                    'fields': {
                        'Alias': 'testuser',
                        'Email': 'test@example.com',
                        'Status': 'active',
                        'bounce_count': 0
                    }
                }
            ]
        }).encode('utf-8')
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Test
        record = handler.find_airtable_record_by_email('test@example.com')

        # Assert
        self.assertIsNotNone(record)
        self.assertEqual(record['id'], 'recABC123')
        self.assertEqual(record['fields']['Email'], 'test@example.com')

    @patch('handler.urllib.request.urlopen')
    @patch('handler.get_airtable_credentials')
    def test_find_record_by_email_not_found(self, mock_creds, mock_urlopen):
        """Test finding Airtable record when email doesn't exist"""
        mock_creds.return_value = {
            'airtable_api_key': 'test_key',
            'airtable_base_id': 'appTEST123',
            'airtable_table_name': 'Email Aliases'
        }

        # Mock empty response
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps({
            'records': []
        }).encode('utf-8')
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Test
        record = handler.find_airtable_record_by_email('nonexistent@example.com')

        # Assert
        self.assertIsNone(record)

    @patch('handler.urllib.request.urlopen')
    @patch('handler.get_airtable_credentials')
    def test_update_airtable_record(self, mock_creds, mock_urlopen):
        """Test updating Airtable record"""
        mock_creds.return_value = {
            'airtable_api_key': 'test_key',
            'airtable_base_id': 'appTEST123',
            'airtable_table_name': 'Email Aliases'
        }

        # Mock successful update response
        mock_response = MagicMock()
        mock_response.read.return_value = json.dumps({
            'id': 'recABC123',
            'fields': {
                'bounce_count': 1,
                'Status': 'bouncing'
            }
        }).encode('utf-8')
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Test
        updates = {'bounce_count': 1, 'Status': 'bouncing'}
        result = handler.update_airtable_record('recABC123', updates)

        # Assert
        self.assertIsNotNone(result)
        self.assertEqual(result['id'], 'recABC123')

    @patch('handler.find_airtable_record_by_email')
    @patch('handler.update_airtable_record')
    def test_handle_permanent_bounce(self, mock_update, mock_find):
        """Test permanent bounce disables alias"""
        # Mock Airtable record
        mock_find.return_value = {
            'id': 'recABC123',
            'fields': {
                'Alias': 'testuser',
                'Email': 'test@example.com',
                'Status': 'active',
                'bounce_count': 0
            }
        }

        # Bounce message
        message = {
            'notificationType': 'Bounce',
            'bounce': {
                'bounceType': 'Permanent',
                'bouncedRecipients': [
                    {'emailAddress': 'test@example.com'}
                ],
                'timestamp': '2026-01-28T12:00:00.000Z'
            }
        }

        # Test
        handler.handle_bounce(message)

        # Assert
        mock_update.assert_called_once()
        call_args = mock_update.call_args[0]
        self.assertEqual(call_args[0], 'recABC123')
        updates = call_args[1]
        self.assertEqual(updates['Status'], 'bouncing')
        self.assertEqual(updates['bounce_count'], 1)
        self.assertEqual(updates['last_bounce_type'], 'Permanent')
        self.assertEqual(updates['last_bounce_date'], '2026-01-28')

    @patch('handler.find_airtable_record_by_email')
    @patch('handler.update_airtable_record')
    def test_handle_transient_bounce(self, mock_update, mock_find):
        """Test transient bounce increments counter but keeps active"""
        mock_find.return_value = {
            'id': 'recABC123',
            'fields': {
                'Alias': 'testuser',
                'Email': 'test@example.com',
                'Status': 'active',
                'bounce_count': 2
            }
        }

        message = {
            'notificationType': 'Bounce',
            'bounce': {
                'bounceType': 'Transient',
                'bouncedRecipients': [
                    {'emailAddress': 'test@example.com'}
                ],
                'timestamp': '2026-01-28T12:00:00.000Z'
            }
        }

        handler.handle_bounce(message)

        call_args = mock_update.call_args[0]
        updates = call_args[1]
        # Transient bounce should NOT change status
        self.assertNotIn('Status', updates)
        self.assertEqual(updates['bounce_count'], 3)
        self.assertEqual(updates['last_bounce_type'], 'Transient')

    @patch('handler.find_airtable_record_by_email')
    @patch('handler.update_airtable_record')
    def test_handle_bounce_no_record(self, mock_update, mock_find):
        """Test bounce handling when no Airtable record exists"""
        mock_find.return_value = None

        message = {
            'notificationType': 'Bounce',
            'bounce': {
                'bounceType': 'Permanent',
                'bouncedRecipients': [
                    {'emailAddress': 'unknown@example.com'}
                ],
                'timestamp': '2026-01-28T12:00:00.000Z'
            }
        }

        # Test - should not raise exception
        handler.handle_bounce(message)

        # Assert - update should not be called
        mock_update.assert_not_called()

    @patch('handler.find_airtable_record_by_email')
    @patch('handler.update_airtable_record')
    def test_handle_complaint(self, mock_update, mock_find):
        """Test complaint disables alias immediately"""
        mock_find.return_value = {
            'id': 'recABC123',
            'fields': {
                'Alias': 'testuser',
                'Email': 'test@example.com',
                'Status': 'active',
                'complaint_count': 0
            }
        }

        message = {
            'notificationType': 'Complaint',
            'complaint': {
                'complainedRecipients': [
                    {'emailAddress': 'test@example.com'}
                ],
                'timestamp': '2026-01-28T12:00:00.000Z'
            }
        }

        handler.handle_complaint(message)

        call_args = mock_update.call_args[0]
        updates = call_args[1]
        self.assertEqual(updates['Status'], 'bouncing')
        self.assertEqual(updates['complaint_count'], 1)
        self.assertEqual(updates['last_complaint_date'], '2026-01-28')

    @patch('handler.find_airtable_record_by_email')
    @patch('handler.update_airtable_record')
    def test_handle_multiple_recipients(self, mock_update, mock_find):
        """Test handling bounce with multiple recipients"""
        mock_find.side_effect = [
            {
                'id': 'recABC123',
                'fields': {'Email': 'test1@example.com', 'bounce_count': 0}
            },
            {
                'id': 'recDEF456',
                'fields': {'Email': 'test2@example.com', 'bounce_count': 1}
            }
        ]

        message = {
            'notificationType': 'Bounce',
            'bounce': {
                'bounceType': 'Permanent',
                'bouncedRecipients': [
                    {'emailAddress': 'test1@example.com'},
                    {'emailAddress': 'test2@example.com'}
                ],
                'timestamp': '2026-01-28T12:00:00.000Z'
            }
        }

        handler.handle_bounce(message)

        # Assert both records were updated
        self.assertEqual(mock_update.call_count, 2)

    @patch('handler.init_sentry')
    @patch('handler.handle_bounce')
    def test_lambda_handler_bounce(self, mock_handle_bounce, mock_init_sentry):
        """Test Lambda handler with bounce notification"""
        event = {
            'Records': [
                {
                    'EventSource': 'aws:sns',
                    'Sns': {
                        'Message': json.dumps({
                            'notificationType': 'Bounce',
                            'bounce': {
                                'bounceType': 'Permanent',
                                'bouncedRecipients': [
                                    {'emailAddress': 'test@example.com'}
                                ],
                                'timestamp': '2026-01-28T12:00:00.000Z'
                            }
                        })
                    }
                }
            ]
        }

        result = handler.lambda_handler(event, None)

        self.assertEqual(result['statusCode'], 200)
        mock_handle_bounce.assert_called_once()
        mock_init_sentry.assert_called_once()

    @patch('handler.init_sentry')
    @patch('handler.handle_complaint')
    def test_lambda_handler_complaint(self, mock_handle_complaint, mock_init_sentry):
        """Test Lambda handler with complaint notification"""
        event = {
            'Records': [
                {
                    'EventSource': 'aws:sns',
                    'Sns': {
                        'Message': json.dumps({
                            'notificationType': 'Complaint',
                            'complaint': {
                                'complainedRecipients': [
                                    {'emailAddress': 'test@example.com'}
                                ],
                                'timestamp': '2026-01-28T12:00:00.000Z'
                            }
                        })
                    }
                }
            ]
        }

        result = handler.lambda_handler(event, None)

        self.assertEqual(result['statusCode'], 200)
        mock_handle_complaint.assert_called_once()

    @patch('handler.init_sentry')
    def test_lambda_handler_unknown_notification(self, mock_init_sentry):
        """Test Lambda handler with unknown notification type"""
        event = {
            'Records': [
                {
                    'EventSource': 'aws:sns',
                    'Sns': {
                        'Message': json.dumps({
                            'notificationType': 'Unknown',
                        })
                    }
                }
            ]
        }

        result = handler.lambda_handler(event, None)

        # Should still return success but log unknown type
        self.assertEqual(result['statusCode'], 200)


if __name__ == '__main__':
    unittest.main()
