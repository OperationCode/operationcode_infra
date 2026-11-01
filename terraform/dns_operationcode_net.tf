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

# Strict DMARC: reject all spoofed mail, send aggregate reports to tech@
resource "aws_route53_record" "net_dmarc" {
  zone_id = aws_route53_zone.operationcode_net.zone_id
  name    = "_dmarc.operationcode.net"
  type    = "TXT"
  ttl     = 3600
  records = ["v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:tech@operationcode.org"]
}

# DMARC report authorization (RFC 7489 section 7.1)
# The rua address is in operationcode.org, a different domain than the one being reported on.
# Receivers only send reports there if the .org zone publishes this record.
# It lives in this file (not dns_operationcode_org.tf) because it exists only to support the .net DMARC record.
# It is created in the operationcode.org zone, so it uses that zone's id.
resource "aws_route53_record" "net_dmarc_report_auth" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "operationcode.net._report._dmarc.operationcode.org"
  type    = "TXT"
  ttl     = 3600
  records = ["v=DMARC1"]
}

# ======================================================================
# Imports (remove after the first successful apply)
# The apex NS/SOA are managed by the zone itself and are not imported.
# The stray operationcode.org.operationcode.net MX/SPF/TXT records are deleted by hand, not imported.
# ======================================================================

import {
  to = aws_route53_zone.operationcode_net
  id = "Z07670273N62ICN43WEHI"
}

import {
  to = aws_route53_record.net_apex_a
  id = "Z07670273N62ICN43WEHI_operationcode.net_A"
}

import {
  to = aws_route53_record.net_www
  id = "Z07670273N62ICN43WEHI_www.operationcode.net_CNAME"
}
