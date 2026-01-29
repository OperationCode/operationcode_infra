# Reference existing Route53 hosted zone
data "aws_route53_zone" "operationcode" {
  name = "operationcode.org."
}

# MX record for SES email receiving
resource "aws_route53_record" "coders_mx" {
  zone_id = data.aws_route53_zone.operationcode.zone_id
  name    = "coders.operationcode.org"
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.us-east-1.amazonaws.com"]
}

# SPF record for email authentication
resource "aws_route53_record" "coders_spf" {
  zone_id = data.aws_route53_zone.operationcode.zone_id
  name    = "coders.operationcode.org"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# DKIM records (3 tokens from SES)
resource "aws_route53_record" "coders_dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.operationcode.zone_id
  name    = "${module.ses_email_forwarder.ses_dkim_tokens[count.index]}._domainkey.coders.operationcode.org"
  type    = "CNAME"
  ttl     = 300
  records = ["${module.ses_email_forwarder.ses_dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# Custom MAIL FROM domain - MX record
resource "aws_route53_record" "coders_bounce_mx" {
  zone_id = data.aws_route53_zone.operationcode.zone_id
  name    = "bounce.coders.operationcode.org"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}

# Custom MAIL FROM domain - SPF record
resource "aws_route53_record" "coders_bounce_spf" {
  zone_id = data.aws_route53_zone.operationcode.zone_id
  name    = "bounce.coders.operationcode.org"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# DMARC record for email policy
# p=quarantine: Failed authentication emails are sent to spam
# adkim=r, aspf=r: Relaxed alignment (allows subdomain alignment like bounce.coders.operationcode.org)
# pct=100: Apply policy to 100% of failing messages
resource "aws_route53_record" "coders_dmarc" {
  zone_id = data.aws_route53_zone.operationcode.zone_id
  name    = "_dmarc.coders.operationcode.org"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=quarantine; adkim=r; aspf=r; pct=100"]
}
