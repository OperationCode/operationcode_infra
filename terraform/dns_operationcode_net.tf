# Route53 zone: operationcode.net
# The domain sends no mail. It only redirects web traffic to operationcode.org,
# so it carries anti-spoofing records (null SPF, null MX, strict DMARC).

# Hosted zone for operationcode.net (imported; never destroy)
resource "aws_route53_zone" "operationcode_net" {
  name = "operationcode.net"
  # Live zone has an empty comment; keep it empty to avoid drift (provider would otherwise default it)
  comment = ""

  lifecycle {
    prevent_destroy = true
  }
}

# ======================================================================
# Apex and web
# ======================================================================

# S3 website endpoint (us-east-1): answers 301 to https://operationcode.org/
resource "aws_route53_record" "net_apex_a" {
  zone_id = aws_route53_zone.operationcode_net.zone_id
  name    = "operationcode.net"
  type    = "A"

  alias {
    name                   = "s3-website-us-east-1.amazonaws.com."
    zone_id                = "Z3AQBSTGFYJSTF"
    evaluate_target_health = true
  }
}

# www CNAME to the apex (live value has no trailing dot; keep it as is)
# Note: the S3 website endpoint returns 403 for the www Host header, so www does not redirect today
resource "aws_route53_record" "net_www" {
  zone_id = aws_route53_zone.operationcode_net.zone_id
  name    = "www.operationcode.net"
  type    = "CNAME"
  ttl     = 300
  records = ["operationcode.net"]
}

# ======================================================================
# Anti-spoofing (domain sends no mail)
# ======================================================================

# Null SPF: No sender is authorized to use operationcode.net as its SPF identity.
resource "aws_route53_record" "net_apex_spf" {
  zone_id = aws_route53_zone.operationcode_net.zone_id
  name    = "operationcode.net"
  type    = "TXT"
  ttl     = 3600
  records = ["v=spf1 -all"]
}

# Null MX (RFC 7505): the domain accepts no mail
resource "aws_route53_record" "net_apex_mx" {
  zone_id = aws_route53_zone.operationcode_net.zone_id
  name    = "operationcode.net"
  type    = "MX"
  ttl     = 3600
  records = ["0 ."]
}

# Strict DMARC: reject all spoofed mail, no aggregate reports
resource "aws_route53_record" "net_dmarc" {
  zone_id = aws_route53_zone.operationcode_net.zone_id
  name    = "_dmarc.operationcode.net"
  type    = "TXT"
  ttl     = 3600
  records = ["v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s"]
}
