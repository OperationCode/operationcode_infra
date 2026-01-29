# AWS SES Email Forwarding System for Operation Code

## Overview

This document describes the architecture and implementation plan for an email forwarding system that:

1. Allows donors who set up recurring donations to receive a custom email alias (e.g., `john@coders.operationcode.org`)
2. Forwards emails sent to that alias to the donor's personal email address
3. Stores alias mappings in Airtable (integrated with existing automation workflows)
4. Notifies a Slack channel when new aliases are created
5. Monitors for lapsed payments and alerts accordingly

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Route 53                                            │
│  MX record: coders.operationcode.org → inbound-smtp.us-east-1.amazonaws.com     │
│  TXT records: SPF, DKIM verification                                            │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS SES (Email Receiving)                           │
│                                                                                  │
│  Receipt Rule Set: "coders-email-forwarding"                                    │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Rule: "forward-to-members"                                              │   │
│  │  Recipients: coders.operationcode.org                                    │   │
│  │  Actions:                                                                │   │
│  │    1. Store in S3 (opcode-ses-incoming-emails bucket)                   │   │
│  │    2. Invoke Lambda (ses-email-forwarder)                               │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                          ┌─────────────┴─────────────┐
                          ▼                           ▼
┌──────────────────────────────────┐    ┌──────────────────────────────────┐
│          S3 Bucket               │    │   Lambda: ses-email-forwarder    │
│   opcode-ses-incoming-emails/    │    │                                  │
│   └── emails/{message-id}        │    │  1. Parse recipient (alias)      │
│       (raw email stored)         │    │  2. Query Airtable for mapping   │
│                                  │    │  3. Fetch email from S3          │
└──────────────────────────────────┘    │  4. Rewrite headers              │
                                        │  5. Forward via SES              │
                                        └──────────────────────────────────┘
                                                        │
                                        ┌───────────────┴───────────────┐
                                        ▼                               ▼
                              ┌──────────────────┐            ┌──────────────┐
                              │     Airtable     │            │  SES Send    │
                              │                  │            │              │
                              │ Email Aliases    │            │ Forward to   │
                              │ Base/Table       │            │ personal     │
                              │                  │            │ email        │
                              └──────────────────┘            └──────────────┘
```

## Provisioning Flow (via Zapier)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         NEW DONOR PROVISIONING                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Stripe Payment Link ──► Stripe Subscription Created ──► Zapier Trigger         │
│                                                              │                   │
│                                                              ▼                   │
│                                                    ┌─────────────────┐          │
│                                                    │ Generate Alias  │          │
│                                                    │ (firstname123)  │          │
│                                                    └────────┬────────┘          │
│                                                             │                   │
│                                                             ▼                   │
│                                                    ┌─────────────────┐          │
│                                                    │ Create Airtable │          │
│                                                    │ Record          │          │
│                                                    └────────┬────────┘          │
│                                                             │                   │
│                                                             ▼                   │
│                                                    ┌─────────────────┐          │
│                                                    │ Slack Notify    │          │
│                                                    │ #new-members    │          │
│                                                    └─────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         LAPSED PAYMENT HANDLING                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Stripe ──► invoice.payment_failed ──► Zapier Trigger                           │
│                                              │                                   │
│                                              ▼                                   │
│                                    ┌─────────────────┐                          │
│                                    │ Find Airtable   │                          │
│                                    │ Record by Email │                          │
│                                    └────────┬────────┘                          │
│                                             │                                   │
│                                             ▼                                   │
│                                    ┌─────────────────┐                          │
│                                    │ Update Status   │                          │
│                                    │ → "lapsed"      │                          │
│                                    └────────┬────────┘                          │
│                                             │                                   │
│                                             ▼                                   │
│                                    ┌─────────────────┐                          │
│                                    │ Slack Alert     │                          │
│                                    │ #payment-issues │                          │
│                                    └─────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. Route 53 DNS Records

Add these records to the `operationcode.org` hosted zone for the `coders` subdomain:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| MX | coders.operationcode.org | `10 inbound-smtp.us-east-1.amazonaws.com` | 300 |
| TXT | coders.operationcode.org | `v=spf1 include:amazonses.com ~all` | 300 |
| CNAME | `{selector1}._domainkey.coders.operationcode.org` | `{provided by SES}` | 300 |
| CNAME | `{selector2}._domainkey.coders.operationcode.org` | `{provided by SES}` | 300 |
| CNAME | `{selector3}._domainkey.coders.operationcode.org` | `{provided by SES}` | 300 |

> **Note:** The DKIM CNAME records will be provided by SES during domain verification. There will be 3 of them.

---

### 2. Airtable Schema

**Base Name:** `Operation Code Automation` (or existing base)

**Table Name:** `Email Aliases`

| Field Name | Field Type | Description | Example |
|------------|------------|-------------|---------|
| `alias` | Single line text (Primary) | The local part of the email | `john482` |
| `full_email` | Formula | `{alias} & "@coders.operationcode.org"` | `john482@coders.operationcode.org` |
| `personal_email` | Email | Donor's real email address | `john@gmail.com` |
| `donor_name` | Single line text | Full name | `John Smith` |
| `status` | Single select | Options: `active`, `lapsed`, `cancelled` | `active` |
| `stripe_customer_id` | Single line text | For payment tracking | `cus_ABC123` |
| `stripe_subscription_id` | Single line text | Subscription reference | `sub_XYZ789` |
| `last_payment_date` | Date | Last successful payment | `2026-01-15` |
| `created_at` | Created time | Auto-populated | `2026-01-01` |
| `notes` | Long text | Admin notes | |

**Views to Create:**
- `Active Aliases` - Filter: status = "active"
- `Lapsed (30+ days)` - Filter: status = "lapsed" OR last_payment_date < 30 days ago
- `All Aliases` - No filter

---

### 3. S3 Bucket

**Bucket Name:** `opcode-ses-incoming-emails`

**Configuration:**
- Region: `us-east-1` (must match SES region)
- Versioning: Disabled (optional, enable if you want email history)
- Encryption: SSE-S3 (default)
- Lifecycle Rule: Delete objects after 7 days (emails are ephemeral, just for forwarding)

**Bucket Policy:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSESPuts",
            "Effect": "Allow",
            "Principal": {
                "Service": "ses.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::opcode-ses-incoming-emails/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceAccount": "${AWS_ACCOUNT_ID}"
                }
            }
        }
    ]
}
```

---

### 4. Lambda Function: `ses-email-forwarder`

**Runtime:** Python 3.12  
**Memory:** 256 MB  
**Timeout:** 30 seconds  
**Architecture:** arm64 (Graviton, cheaper)

**Environment Variables:**

| Variable | Value |
|----------|-------|
| `EMAIL_BUCKET` | `opcode-ses-incoming-emails` |
| `AIRTABLE_API_KEY` | `pat...` (Personal Access Token) |
| `AIRTABLE_BASE_ID` | `app...` (from Airtable URL) |
| `AIRTABLE_TABLE_NAME` | `Email Aliases` |
| `FORWARD_FROM_EMAIL` | `noreply@coders.operationcode.org` |
| `AWS_SES_REGION` | `us-east-1` |

**IAM Role Policy:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::opcode-ses-incoming-emails/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendRawEmail"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
```

**Lambda Function Code:**

```python
import boto3
import email
import os
import json
import urllib.request
import urllib.error
from email import policy
from email.parser import BytesParser
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

# Configuration from environment variables
EMAIL_BUCKET = os.environ['EMAIL_BUCKET']
AIRTABLE_API_KEY = os.environ['AIRTABLE_API_KEY']
AIRTABLE_BASE_ID = os.environ['AIRTABLE_BASE_ID']
AIRTABLE_TABLE_NAME = os.environ['AIRTABLE_TABLE_NAME']
FORWARD_FROM_EMAIL = os.environ['FORWARD_FROM_EMAIL']
AWS_SES_REGION = os.environ.get('AWS_SES_REGION', 'us-east-1')

s3_client = boto3.client('s3')
ses_client = boto3.client('ses', region_name=AWS_SES_REGION)


def lookup_alias_in_airtable(alias: str) -> dict | None:
    """
    Query Airtable to find the mapping for a given alias.
    Returns the record if found and active, None otherwise.
    """
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{urllib.parse.quote(AIRTABLE_TABLE_NAME)}"
    
    # Filter for exact alias match
    params = urllib.parse.urlencode({
        'filterByFormula': f"AND({{alias}} = '{alias}', {{status}} = 'active')",
        'maxRecords': 1
    })
    
    full_url = f"{url}?{params}"
    
    req = urllib.request.Request(
        full_url,
        headers={
            'Authorization': f'Bearer {AIRTABLE_API_KEY}',
            'Content-Type': 'application/json'
        }
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            records = data.get('records', [])
            if records:
                return records[0]['fields']
            return None
    except urllib.error.HTTPError as e:
        print(f"Airtable API error: {e.code} - {e.read().decode()}")
        return None


def get_email_from_s3(message_id: str) -> bytes:
    """Retrieve the raw email from S3."""
    response = s3_client.get_object(
        Bucket=EMAIL_BUCKET,
        Key=message_id
    )
    return response['Body'].read()


def forward_email(raw_email: bytes, forward_to: str, original_recipient: str) -> dict:
    """
    Parse the original email and forward it to the destination address.
    Rewrites headers to comply with SES requirements while preserving
    the original sender information.
    """
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
    new_msg['From'] = FORWARD_FROM_EMAIL
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
    response = ses_client.send_raw_email(
        Source=FORWARD_FROM_EMAIL,
        Destinations=[forward_to],
        RawMessage={'Data': new_msg.as_bytes()}
    )
    
    return response


def handler(event, context):
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
    """
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
                # Optionally: bounce the email or silently drop
                continue
            
            forward_to = mapping.get('personal_email')
            donor_name = mapping.get('donor_name', 'Member')
            
            if not forward_to:
                print(f"No personal_email in mapping for alias: {alias}")
                continue
            
            print(f"Forwarding to: {forward_to} ({donor_name})")
            
            try:
                # Get the raw email from S3
                raw_email = get_email_from_s3(message_id)
                
                # Forward it
                response = forward_email(raw_email, forward_to, recipient)
                print(f"Successfully forwarded. SES MessageId: {response.get('MessageId')}")
                
            except Exception as e:
                print(f"Error forwarding email: {str(e)}")
                raise
    
    return {
        'statusCode': 200,
        'body': 'Processed'
    }
```

**Required Python Packages:**
- None beyond standard library (boto3 is included in Lambda runtime)

**Lambda Resource-based Policy (allow SES to invoke):**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSESInvoke",
            "Effect": "Allow",
            "Principal": {
                "Service": "ses.amazonaws.com"
            },
            "Action": "lambda:InvokeFunction",
            "Resource": "arn:aws:lambda:us-east-1:${AWS_ACCOUNT_ID}:function:ses-email-forwarder",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceAccount": "${AWS_ACCOUNT_ID}"
                }
            }
        }
    ]
}
```

---

### 5. SES Configuration

#### Domain Identity Verification

1. Go to SES Console → Identities → Create Identity
2. Select "Domain"
3. Enter: `coders.operationcode.org`
4. Enable "Easy DKIM"
5. SES will provide DNS records to add to Route 53

#### Receipt Rule Set

**Rule Set Name:** `coders-email-forwarding`

**Rule Configuration:**
- **Rule Name:** `forward-to-members`
- **Recipients:** `coders.operationcode.org` (catches all addresses on this subdomain)
- **Actions (in order):**
  1. **S3 Action:**
     - Bucket: `opcode-ses-incoming-emails`
     - Object key prefix: (leave empty)
  2. **Lambda Action:**
     - Function: `ses-email-forwarder`
     - Invocation type: `Event` (asynchronous)

> **Important:** The rule set must be set as the "Active" rule set.

#### Sending Authorization

After domain verification, verify that `noreply@coders.operationcode.org` can send emails:
- The domain verification covers all addresses on that domain
- No additional email verification needed

---

### 6. Zapier Zaps

#### Zap 1: New Stripe Subscription → Create Email Alias

**Trigger:**
- App: Stripe
- Event: New Subscription

**Action 1: Code by Zapier (Generate Alias)**
```javascript
// Input: customer_name, customer_email from Stripe
const firstName = inputData.customer_name.split(' ')[0].toLowerCase();
const randomSuffix = Math.floor(Math.random() * 900) + 100; // 3 digits
const alias = `${firstName}${randomSuffix}`;
return { alias: alias };
```

**Action 2: Airtable - Create Record**
- Base: Operation Code Automation
- Table: Email Aliases
- Fields:
  - alias: `{{alias from Step 2}}`
  - personal_email: `{{Customer Email from Stripe}}`
  - donor_name: `{{Customer Name from Stripe}}`
  - status: `active`
  - stripe_customer_id: `{{Customer ID from Stripe}}`
  - stripe_subscription_id: `{{Subscription ID from Stripe}}`
  - last_payment_date: `{{Current Date}}`

**Action 3: Slack - Send Channel Message**
- Channel: `#coders-members` (or appropriate channel)
- Message:
```
🎉 *New Coders Member!*
• Name: {{donor_name}}
• Email alias: {{alias}}@coders.operationcode.org
• Forwards to: {{personal_email}}
```

---

#### Zap 2: Stripe Payment Failed → Update Status & Alert

**Trigger:**
- App: Stripe
- Event: Invoice Payment Failed

**Action 1: Airtable - Find Record**
- Base: Operation Code Automation
- Table: Email Aliases
- Search Field: `stripe_customer_id`
- Search Value: `{{Customer ID from Stripe}}`

**Action 2: Airtable - Update Record** (only if found)
- Record ID: `{{Record ID from Step 2}}`
- status: `lapsed`

**Action 3: Slack - Send Channel Message**
- Channel: `#coders-admin` (or appropriate channel)
- Message:
```
⚠️ *Payment Failed - Member Status Updated*
• Name: {{donor_name from Airtable}}
• Email alias: {{alias}}@coders.operationcode.org
• Personal email: {{personal_email}}
• Stripe Customer: {{Customer ID}}

The member's email forwarding is still active but marked as lapsed.
```

---

#### Zap 3: Stripe Subscription Cancelled → Disable Forwarding

**Trigger:**
- App: Stripe
- Event: Subscription Updated (filter for status = "canceled")

**Action 1: Airtable - Find Record**
- Search by `stripe_subscription_id`

**Action 2: Airtable - Update Record**
- status: `cancelled`

**Action 3: Slack - Send Channel Message**
```
📧 *Subscription Cancelled*
• Name: {{donor_name}}
• Email alias: {{alias}}@coders.operationcode.org (now inactive)
```

---

#### Zap 4 (Optional): Weekly Lapsed Member Report

**Trigger:**
- App: Schedule by Zapier
- Event: Every Week on Monday

**Action 1: Airtable - Find Records**
- View: `Lapsed (30+ days)`

**Action 2: Slack - Send Channel Message**
```
📊 *Weekly Lapsed Members Report*
{{Count}} members with lapsed payments:
{{List of names and aliases}}
```

---

## Cost Estimate (10-20 Users)

### Assumptions
- 10-20 active email aliases
- Each user receives ~50 emails/month (500-1000 total incoming)
- Average email size: 50KB
- All emails are forwarded

### Monthly Costs

| Service | Usage | Unit Cost | Monthly Cost |
|---------|-------|-----------|--------------|
| **SES Receiving** | 1,000 emails | $0.10/1,000 | $0.10 |
| **SES Receiving (chunks)** | ~200 chunks (larger emails) | $0.09/1,000 | $0.02 |
| **SES Sending** | 1,000 emails (forwarded) | $0.10/1,000 | $0.10 |
| **SES Outbound Data** | ~50MB | $0.12/GB | $0.01 |
| **S3 Storage** | ~50MB (7-day retention) | $0.023/GB | ~$0.00 |
| **S3 Requests** | ~2,000 PUT/GET | $0.005/1,000 | $0.01 |
| **Lambda Invocations** | 1,000 | Free tier (1M/mo) | $0.00 |
| **Lambda Compute** | ~500 GB-seconds | Free tier (400K/mo) | $0.00 |
| **Route 53** | Hosted zone already exists | — | $0.00 |
| **Airtable** | Free tier or existing plan | — | $0.00 |

### **Total Estimated Monthly Cost: $0.25 - $0.50**

### Free Tier Coverage (First 12 Months)

| Service | Free Tier Allowance | Your Usage | Status |
|---------|---------------------|------------|--------|
| SES | 3,000 messages/mo | ~2,000 | ✅ Covered |
| Lambda Requests | 1M/mo | ~1,000 | ✅ Covered |
| Lambda Compute | 400K GB-sec/mo | ~500 | ✅ Covered |
| S3 Storage | 5GB | ~50MB | ✅ Covered |

**First 12 months: Essentially $0**  
**After free tier expires: ~$0.25-0.50/month**

---

## Implementation Checklist

### Phase 1: AWS Infrastructure

- [ ] **S3 Bucket**
  - [ ] Create bucket `opcode-ses-incoming-emails` in us-east-1
  - [ ] Apply bucket policy for SES access
  - [ ] Configure lifecycle rule (7-day expiration)

- [ ] **SES Domain Verification**
  - [ ] Add `coders.operationcode.org` as identity in SES
  - [ ] Copy DKIM CNAME records
  - [ ] Request production access (exit sandbox) if not already done

- [ ] **Route 53 DNS Records**
  - [ ] Add MX record for `coders` subdomain
  - [ ] Add SPF TXT record
  - [ ] Add DKIM CNAME records (3)
  - [ ] Wait for verification (up to 72 hours, usually faster)

- [ ] **Lambda Function**
  - [ ] Create IAM role with required permissions
  - [ ] Deploy `ses-email-forwarder` function
  - [ ] Configure environment variables
  - [ ] Add resource-based policy for SES invocation

- [ ] **SES Receipt Rules**
  - [ ] Create rule set `coders-email-forwarding`
  - [ ] Create rule with S3 + Lambda actions
  - [ ] Set rule set as active

### Phase 2: Airtable Setup

- [ ] Create `Email Aliases` table with schema above
- [ ] Create views: Active Aliases, Lapsed, All
- [ ] Generate Airtable Personal Access Token
- [ ] Test API access

### Phase 3: Zapier Integration

- [ ] Create Zap: Stripe Subscription → Airtable + Slack
- [ ] Create Zap: Stripe Payment Failed → Update Airtable + Slack
- [ ] Create Zap: Stripe Cancelled → Update Airtable + Slack
- [ ] (Optional) Create Zap: Weekly lapsed report

### Phase 4: Testing

- [ ] Create test record in Airtable manually
- [ ] Send test email to `test@coders.operationcode.org`
- [ ] Verify email arrives at destination
- [ ] Test with email containing attachment
- [ ] Test non-existent alias (should not forward)
- [ ] Test lapsed status (should not forward)
- [ ] Simulate Stripe subscription via test mode
- [ ] Verify full end-to-end flow

---

## Troubleshooting

### Email not being received by SES

1. Check MX record propagation: `dig MX coders.operationcode.org`
2. Verify domain is verified in SES console
3. Check that receipt rule set is **active**

### Email received but not forwarded

1. Check CloudWatch Logs for Lambda function
2. Verify Airtable API key is valid
3. Check that alias exists in Airtable with status = "active"
4. Verify S3 bucket has the email object

### Forwarded email going to spam

1. Ensure SPF record is correct
2. Verify DKIM is passing (check email headers)
3. Consider adding DMARC record:
   ```
   _dmarc.coders.operationcode.org TXT "v=DMARC1; p=none; rua=mailto:admin@operationcode.org"
   ```

### Lambda timeout

1. Increase timeout to 60 seconds
2. Check Airtable API response time
3. Check for large attachments (>10MB may fail)

---

## Security Considerations

1. **Airtable API Key:** Store in Lambda environment variables (encrypted at rest)
2. **S3 Bucket:** Not public, only SES can write, only Lambda can read
3. **Email Content:** Stored temporarily in S3, deleted after 7 days
4. **Spam Protection:** SES provides built-in spam/virus scanning
5. **Rate Limiting:** Consider CloudWatch alarm for unusual volume spikes

---

## Future Enhancements

1. **User Self-Service:** Allow donors to choose their own alias via a web form
2. **Alias Validation:** Check for duplicates before creating
3. **Email Analytics:** Track forwarding success/failure rates
4. **Bounce Handling:** Update Airtable if forwarding fails
5. **Custom Reply-From:** Allow sending FROM the alias (requires more SES config)
