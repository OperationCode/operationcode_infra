# Email Forwarding System for Operation Code

## Overview

The email forwarding system allows Operation Code donors with recurring donations to receive personalized email aliases at `@coders.operationcode.org`. Emails sent to these aliases are automatically forwarded to the donor's personal email address.

## System Architecture

```
External Sender
      │
      ▼
┌─────────────────────────────────────────┐
│  Route 53 DNS                            │
│  • MX: coders → SES inbound endpoint    │
│  • SPF, DKIM records for authentication │
│  • Custom MAIL FROM (bounce subdomain)  │
│  • DMARC policy (quarantine)            │
└─────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────┐
│  AWS SES (Email Receiving)               │
│  • Receives all @coders.operationcode   │
│  • Receipt rule set (active)            │
│  • Spam/virus scanning                  │
└─────────────────────────────────────────┘
      │
      ├──────────────────┬─────────────────┐
      ▼                  ▼                 ▼
┌────────────┐  ┌─────────────────┐  ┌────────────────┐
│ S3 Bucket  │  │ Lambda Function │  │ Configuration  │
│            │  │ Email           │  │ Set            │
│ Stores raw │  │ Forwarder       │  │                │
│ emails for │  │                 │  │ Routes bounces │
│ 7 days     │  │ 1. Parse alias  │  │ & complaints   │
│            │  │ 2. Query        │  │ to SNS         │
│            │  │    Airtable     │  │                │
│            │  │ 3. Fetch from   │  └────────────────┘
│            │  │    S3           │           │
│            │  │ 4. Rewrite      │           │
│            │  │    headers      │           ▼
│            │  │ 5. Forward via  │  ┌────────────────┐
│            │  │    SES          │  │ SNS Topics     │
└────────────┘  └─────────────────┘  │ • Bounces      │
                         │            │ • Complaints   │
       ┌─────────────────┼────────────┘                │
       │                 │                              │
       ▼                 ▼                              ▼
┌────────────┐  ┌──────────────┐           ┌──────────────────┐
│ Airtable   │  │ SES Sending  │           │ Lambda Function  │
│            │  │              │           │ Bounce           │
│ Email      │  │ Forwards to  │           │ Handler          │
│ Aliases    │  │ personal     │           │                  │
│ Base       │  │ email        │           │ Updates Airtable │
│            │  │              │           │ on bounces       │
│ Fields:    │  │ From:        │           └──────────────────┘
│ • Alias    │  │ noreply@     │
│ • Email    │  │ coders...    │
│ • Name     │  │              │
│ • Status   │  │ Envelope:    │
│            │  │ bounce.      │
│            │  │ coders...    │
└────────────┘  └──────────────┘
```

## How Email Flows

### Incoming Email Flow

1. **External sender** sends email to `john482@coders.operationcode.org`
2. **DNS (Route 53)** directs email to AWS SES via MX record
3. **SES** receives email and applies receipt rules:
   - Action 1: Store raw email in S3 bucket
   - Action 2: Invoke Lambda function for email forwarding
4. **Lambda** processes the email:
   - Extracts alias (`john482`) from recipient address
   - Queries Airtable for mapping (must have `status = "active"`)
   - Fetches raw email from S3
   - Parses and reconstructs email with new headers:
     - `From:` changes to `noreply@coders.operationcode.org`
     - `Reply-To:` set to original sender
     - `To:` set to donor's personal email
     - Original headers preserved in `X-Original-*` headers
   - Sends forwarded email via SES using configuration set
5. **SES** sends email with:
   - **From header**: `noreply@coders.operationcode.org`
   - **Envelope sender (MAIL FROM)**: `bounce.coders.operationcode.org`
   - DKIM signature applied
6. **Recipient** receives email at their personal address

### Bounce/Complaint Handling

1. **SES** detects bounce or complaint
2. **Configuration set** routes event to appropriate SNS topic
3. **SNS** invokes Lambda function for bounce/complaint handling
4. **Lambda** processes notification:
   - Parses bounce/complaint data
   - Updates Airtable record status if needed
   - Logs event details

## Key Components

### 1. DNS Configuration (Route53)

**Main Domain Records** (`coders.operationcode.org`):
- **MX**: Points to SES inbound endpoint
- **SPF (TXT)**: Authorizes SES to send mail
- **DKIM (CNAME × 3)**: Email authentication signatures
- **DMARC (TXT)**: Email policy with quarantine enforcement

**Custom MAIL FROM Subdomain** (`bounce.coders.operationcode.org`):
- **MX**: Points to SES feedback endpoint
- **SPF (TXT)**: Authorizes SES for bounce handling

This configuration enables **DMARC alignment** by ensuring the envelope sender domain matches the organizational domain.

### 2. Airtable Database

**Table**: `Email Aliases`

Critical fields used by the system:
- `Alias`: Email alias (e.g., `john482`)
- `Email`: Destination email address
- `Name`: Donor name (used in logging)
- `Status`: Must be `"active"` for forwarding to work

**Status Values**:
- `active`: Forwarding enabled
- `lapsed`: Payment issue (still forwards, but marked)
- `cancelled`: Forwarding disabled

### 3. Lambda Functions

#### Email Forwarder Lambda
- **Runtime**: Python 3.12 (arm64)
- **Timeout**: 30 seconds
- **Memory**: 256 MB
- **Trigger**: SES receipt rule
- **Purpose**: Forward emails to donors

**Environment Variables**:
- `EMAIL_BUCKET`: S3 bucket name
- `AIRTABLE_SECRET_NAME`: Secrets Manager secret reference (cross-region)
- `FORWARD_FROM_EMAIL`: Configured no-reply address
- `AWS_SES_REGION`: SES region
- `ENVIRONMENT`: Environment name

**Permissions**:
- Read from S3 bucket
- Send raw email via SES
- Read secrets from Secrets Manager (us-east-2)
- Write CloudWatch Logs

#### Bounce Handler Lambda
- **Runtime**: Python 3.12 (arm64)
- **Timeout**: 30 seconds
- **Memory**: 256 MB
- **Trigger**: SNS topics (bounces and complaints)
- **Purpose**: Track delivery issues in Airtable

**Environment Variables**:
- `AIRTABLE_SECRET_NAME`: Secrets Manager secret reference
- `ENVIRONMENT`: Environment name

**Permissions**:
- Read secrets from Secrets Manager
- Write CloudWatch Logs

### 4. S3 Bucket

**Region**: `us-east-1`

**Features**:
- Server-side encryption (AES256)
- Lifecycle policy: Delete objects after 7 days
- Bucket policy: Only SES can write, only Lambda can read

### 5. SES Configuration

**Domain Identity**: `coders.operationcode.org`
- DKIM enabled (3 CNAME records)
- Custom MAIL FROM domain: `bounce.coders.operationcode.org`

**Receipt Rule Set**: Active rule set configured to:
- Receive all emails to `coders.operationcode.org`
- **Actions**:
  1. Store in S3
  2. Invoke Lambda

**Configuration Set**: Configured to:
- Route bounce events to SNS topic
- Route complaint events to SNS topic
- Enable reputation metrics

## Email Authentication & Deliverability

### DKIM (DomainKeys Identified Mail)
- AWS SES automatically signs all outgoing emails
- Three DKIM selectors provide redundancy
- Validates that email came from Operation Code domain

### SPF (Sender Policy Framework)
Records at two levels:
1. **Main domain** (`coders.operationcode.org`): Authorizes SES to send
2. **Bounce subdomain** (`bounce.coders.operationcode.org`): Authorizes SES for envelope sender

### DMARC (Domain-based Message Authentication)
- **Policy**: `p=quarantine` (failed emails go to spam)
- **Alignment**: `adkim=r; aspf=r` (relaxed mode)
  - Allows `bounce.coders.operationcode.org` to align with `coders.operationcode.org`
  - Allows `noreply@coders.operationcode.org` in From header
- **Coverage**: `pct=100` (applies to all messages)

### Custom MAIL FROM Domain
- **Purpose**: Achieves DMARC alignment
- **Implementation**: `bounce.coders.operationcode.org`
- **How it works**:
  - Email headers show: `From: noreply@coders.operationcode.org`
  - Email envelope shows: `MAIL FROM: bounce.coders.operationcode.org`
  - Both domains share organizational domain (`operationcode.org`)
  - DMARC passes with relaxed alignment
- **Fallback**: If DNS fails, SES uses `amazonses.com` as envelope sender

## Secrets Management

Sensitive credentials stored in **AWS Secrets Manager**:

**Configuration**:
- Cross-region access (Lambda in us-east-1, Secrets in us-east-2)
- Contains Airtable API credentials and table configuration
- Contains monitoring/alerting DSN for error tracking

**Secret Contents**:
- Airtable API key
- Airtable base ID and table name
- Error monitoring DSN

## Monitoring & Observability

### CloudWatch Logs
- Lambda functions log to CloudWatch Logs (14-day retention)
- Logs capture:
  - Incoming email metadata
  - Alias lookups (success/failure)
  - Forwarding operations
  - Errors and exceptions

### Error Monitoring Integration
- Both Lambda functions integrated with error monitoring service
- Error tracking and alerting
- Transaction sampling for performance monitoring
- Environment tagging for filtering

### SES Metrics
- Configuration set enables reputation tracking
- Bounce and complaint rates monitored
- Available in SES console

## Provisioning New Aliases

The system is designed to integrate with external automation (e.g., Zapier):

1. **Stripe subscription created** (recurring donation)
2. **Automation generates alias** (e.g., `firstname123`)
3. **Airtable record created** with:
   - `Alias`: Generated alias
   - `Email`: Donor's email address
   - `Name`: Donor's name
   - `Status`: `active`
   - `Stripe customer_id` and `subscription_id`
4. **Email immediately functional** (no infrastructure changes needed)

## Handling Lapsed Payments

When a payment fails:

1. **Stripe webhook** triggers (e.g., `invoice.payment_failed`)
2. **Automation updates Airtable** record:
   - Set `Status` to `lapsed`
3. **Email forwarding continues** (status check looks for "active" but system is lenient)
4. **Notification sent** to admin channel

**Note**: Current implementation forwards emails regardless of status. If strict enforcement is needed, Lambda code can be modified to check status.

## Security Considerations

1. **Secrets**: Stored in Secrets Manager, never in code or environment variables
2. **S3 Bucket**: Private, restrictive bucket policy
3. **Email Retention**: Automatic deletion after 7 days
4. **Spam Protection**: SES provides built-in scanning
5. **Cross-Region Access**: Lambda in us-east-1 securely reads secrets from us-east-2
6. **IAM Roles**: Least-privilege permissions for all resources

## Cost Estimate

For 10-20 active aliases receiving ~50 emails/month each:

**Monthly AWS Costs**:
- SES Receiving: ~$0.10
- SES Sending: ~$0.10
- S3 Storage & Requests: ~$0.02
- Lambda: $0.00 (within free tier)
- Secrets Manager: ~$0.40/secret/month

**Total**: ~$0.60-0.80/month

**Note**: First 12 months may be less due to AWS Free Tier covering SES and Lambda usage.

## Troubleshooting

### Email Not Forwarded

1. **Check CloudWatch Logs**: Lambda function logs
   - Look for alias lookup failures
   - Check for Airtable API errors
2. **Verify Airtable**:
   - Record exists for alias
   - `Status` is `"active"`
   - `Email` field is populated
3. **Check S3**: Verify email object exists in bucket
4. **SES Receipt Rule**: Ensure rule set is active

### Emails Going to Spam

1. **Check DKIM**: Verify all 3 CNAME records are in DNS
2. **Check SPF**: Verify both SPF records exist (main + bounce subdomain)
3. **Check DMARC**: Verify DMARC record exists and alignment is working
4. **Check Email Headers**: Look for authentication results

### DNS Issues

Use these commands to verify DNS propagation:
```bash
dig MX coders.operationcode.org
dig TXT coders.operationcode.org
dig TXT bounce.coders.operationcode.org
dig MX bounce.coders.operationcode.org
dig TXT _dmarc.coders.operationcode.org
```

## Implementation Files

**Infrastructure (Terraform)**:
- [terraform/ses_email_forwarding.tf](terraform/ses_email_forwarding.tf) - Module invocation
- [terraform/ses_email_forwarding/main.tf](terraform/ses_email_forwarding/main.tf) - SES and Lambda resources
- [terraform/ses_email_forwarding/bounce_handling.tf](terraform/ses_email_forwarding/bounce_handling.tf) - Bounce handling infrastructure
- [terraform/route53.tf](terraform/route53.tf) - DNS records

**Application Code**:
- [lambda/ses_email_forwarder/handler.py](lambda/ses_email_forwarder/handler.py) - Email forwarding logic
- [lambda/ses_bounce_handler/handler.py](lambda/ses_bounce_handler/handler.py) - Bounce processing logic

**Documentation**:
- [plans/ses-email-forwarding-guide.md](plans/ses-email-forwarding-guide.md) - Original implementation plan

## Differences from Original Plan

The actual implementation differs from the original plan in these ways:

1. **Secrets Management**: Uses AWS Secrets Manager instead of Lambda environment variables
2. **Cross-Region Architecture**: Secrets in us-east-2, SES/Lambda in us-east-1
3. **Bounce Handling**: Added comprehensive bounce/complaint handling with SNS and second Lambda
4. **DMARC Configuration**: Added custom MAIL FROM domain and DMARC policy with quarantine
5. **Error Monitoring**: Added error monitoring and alerting integration
6. **Airtable Field Names**: Uses `Email` and `Alias` instead of `personal_email` and `alias`
7. **Configuration Set**: Added for bounce tracking and reputation metrics
8. **Encryption**: S3 bucket uses server-side encryption

## Future Enhancements

Potential improvements to consider:

1. **DLQ (Dead Letter Queue)**: Capture and retry failed forwarding attempts
2. **CloudWatch Alarms**: Alert on high error rates or unusual volume
3. **Email Analytics**: Dashboard showing forwarding metrics
4. **Alias Validation**: Prevent duplicate aliases at creation time
5. **Self-Service Portal**: Allow donors to manage their own aliases
6. **Reply-From Feature**: Enable sending FROM the alias address (requires additional SES configuration)
