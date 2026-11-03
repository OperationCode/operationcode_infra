# DNSSEC signing and query logging for operationcode.org
# Zone: aws_route53_zone.operationcode (dns_operationcode_org.tf)
# Route53 requires the DNSSEC KMS key and the query log group in us-east-1.

# ======================================================================
# DNSSEC signing (stage 1 of 2: sign the zone; no DS record at the registrar yet)
# ======================================================================

# Key policy:
# - account root: full admin, so IAM policies control key management
# - Route53 DNSSEC service: read the public key and sign, only for hosted zones in this account
# - Route53 DNSSEC service: create grants, only for AWS resources
data "aws_iam_policy_document" "dnssec_kms" {
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowRoute53DNSSECService"
    effect    = "Allow"
    actions   = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:route53:::hostedzone/*"]
    }
  }

  statement {
    sid       = "AllowRoute53DNSSECToCreateGrant"
    effect    = "Allow"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

# Asymmetric signing key for the KSK. Deleting it breaks resolution once the DS record is live; never destroy
resource "aws_kms_key" "dnssec" {
  provider                 = aws.us_east_1
  description              = "Route53 DNSSEC KSK for operationcode.org"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 7
  policy                   = data.aws_iam_policy_document.dnssec_kms.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "dnssec" {
  provider      = aws.us_east_1
  name          = "alias/route53-dnssec-operationcode-org"
  target_key_id = aws_kms_key.dnssec.key_id
}

resource "aws_route53_key_signing_key" "operationcode" {
  hosted_zone_id             = aws_route53_zone.operationcode.id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                       = "operationcode_org_ksk"
}

resource "aws_route53_hosted_zone_dnssec" "operationcode" {
  hosted_zone_id = aws_route53_key_signing_key.operationcode.hosted_zone_id

  depends_on = [aws_route53_key_signing_key.operationcode]
}

# Stage 2: DS record at the registrar (Route53 Domains, us-east-1). This completes the DNSSEC
# chain of trust from .org to this zone. Enabled 2026-11-03, after signing ran for 53 hours
# (longer than the 48h apex NS TTL) and every checked RRset validated against KSK tag 23956.
# Rollback order: remove this DS record first, wait for the DS TTL at the .org parent (and the
# registrar change) to pass, then disable signing (aws_route53_hosted_zone_dnssec signing_status = "NOT_SIGNING").
# Disabling signing or deleting the KSK while the DS record is live makes the domain fail
# resolution for validating resolvers.
resource "aws_route53domains_delegation_signer_record" "operationcode" {
  provider    = aws.us_east_1
  domain_name = "operationcode.org"

  signing_attributes {
    algorithm  = aws_route53_key_signing_key.operationcode.signing_algorithm_type
    flags      = aws_route53_key_signing_key.operationcode.flag
    public_key = aws_route53_key_signing_key.operationcode.public_key
  }

  # The provider does not read signing_attributes back (import and refresh leave them empty),
  # which would force a destroy/recreate of the live DS record. A KSK rotation needs a new DS
  # record anyway, so ignore drift here and replace the DS deliberately during a rotation.
  lifecycle {
    ignore_changes = [signing_attributes]
  }

  depends_on = [aws_route53_hosted_zone_dnssec.operationcode]
}
# ======================================================================
# Query logging
# ======================================================================

resource "aws_cloudwatch_log_group" "route53_query_operationcode" {
  provider          = aws.us_east_1
  name              = "/aws/route53/operationcode.org"
  retention_in_days = 30
}

# Account-wide policy (us-east-1 limit: 10 per region) that lets Route53 write any /aws/route53/* log group
data "aws_iam_policy_document" "route53_query_logging" {
  statement {
    sid       = "Route53QueryLogging"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/route53/*"]

    principals {
      type        = "Service"
      identifiers = ["route53.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:route53:::hostedzone/*"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_logging" {
  provider        = aws.us_east_1
  policy_name     = "route53-query-logging"
  policy_document = data.aws_iam_policy_document.route53_query_logging.json
}

resource "aws_route53_query_log" "operationcode" {
  zone_id                  = aws_route53_zone.operationcode.zone_id
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_operationcode.arn

  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_logging]
}
