# Route53 zone: operationcode.org
# A sibling dns_operationcode_net.tf is planned for operationcode.net.

# Hosted zone for operationcode.org (imported; never destroy)
resource "aws_route53_zone" "operationcode" {
  name = "operationcode.org"
  # Live zone has an empty comment; keep it empty to avoid drift (provider would otherwise default it)
  comment = ""

  lifecycle {
    prevent_destroy = true
  }
}

# ======================================================================
# Apex and web
# ======================================================================

# Vercel: apex website
resource "aws_route53_record" "apex_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "operationcode.org"
  type    = "A"
  ttl     = 300
  records = ["76.76.21.21"]
}

# CA policy: restricts wildcard issuance to Amazon, reports to tech@
resource "aws_route53_record" "apex_caa" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "operationcode.org"
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issuewild \"amazontrust.com\"",
    "0 issuewild \"amazon.com\"",
    "0 iodef \"mailto:tech@operationcode.org\"",
  ]
}

# Vercel: website
resource "aws_route53_record" "www_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "www.operationcode.org"
  type    = "A"
  ttl     = 300
  records = ["76.76.21.21"]
}

# Vercel: Storybook
resource "aws_route53_record" "storybook" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "storybook.operationcode.org"
  type    = "CNAME"
  ttl     = 600
  records = ["cname.vercel-dns.com."]
}

# ======================================================================
# App hosts (ALB aliases to the ECS cluster)
# ======================================================================

# ALB alias for the production backend API (ECS python_backend_prod)
resource "aws_route53_record" "api_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "api.operationcode.org"
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = false
  }
}

# ALB alias for the production backend API (ECS python_backend_prod)
resource "aws_route53_record" "api_aaaa" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "api.operationcode.org"
  type    = "AAAA"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = false
  }
}

# ALB alias for pybot (ECS pybot_prod)
resource "aws_route53_record" "pybot_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "pybot.operationcode.org"
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = false
  }
}

# ALB alias for pybot (ECS pybot_prod)
resource "aws_route53_record" "pybot_aaaa" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "pybot.operationcode.org"
  type    = "AAAA"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = false
  }
}

# ALB alias; listener rule redirects to https://www.operationcode.org
resource "aws_route53_record" "resources_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "resources.operationcode.org"
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = false
  }
}

# Note: evaluate_target_health = true here but false on resources_a; this matches live, do not unify.
# ALB alias; listener rule redirects to https://www.operationcode.org
resource "aws_route53_record" "resources_aaaa" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "resources.operationcode.org"
  type    = "AAAA"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = true
  }
}

# ======================================================================
# Staging
# ======================================================================

# ALB alias for the staging backend API (ECS python_backend_staging)
resource "aws_route53_record" "api_staging_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "api.staging.operationcode.org"
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = false
  }
}

# ALB alias for the staging backend API (ECS python_backend_staging)
resource "aws_route53_record" "api_staging_aaaa" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "api.staging.operationcode.org"
  type    = "AAAA"

  alias {
    name                   = "dualstack.${aws_lb.ecs.dns_name}"
    zone_id                = aws_lb.ecs.zone_id
    evaluate_target_health = false
  }
}

# ======================================================================
# Email: Google Workspace, apex SPF/DMARC
# ======================================================================

# Google Workspace mail
resource "aws_route53_record" "apex_mx" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "operationcode.org"
  type    = "MX"
  ttl     = 3600
  records = [
    "1 ASPMX.L.GOOGLE.COM.",
    "5 ALT1.ASPMX.L.GOOGLE.COM.",
    "5 ALT2.ASPMX.L.GOOGLE.COM.",
    "10 ALT3.ASPMX.L.GOOGLE.COM.",
    "10 ALT4.ASPMX.L.GOOGLE.COM.",
  ]
}

# SPF (Google, Mailgun, Mandrill) and Google site verification. Keep the Mandrill include (production mail uses it). INVESTIGATE: Mailgun include is unused by code, confirm with the Mailgun account
resource "aws_route53_record" "apex_txt" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "operationcode.org"
  type    = "TXT"
  ttl     = 3600
  records = [
    "v=spf1 a include:_spf.google.com include:mailgun.org include:spf.mandrillapp.com ~all",
    "google-site-verification=XFeRZYknCzfwk5LTAuVDKf6T99S-DGafkhOfUlFXwFI",
    "google-site-verification=s2E7tZyPlszu8LHIcYlRT8s6oq6hSoGQ70gMXKP08aE",
  ]
}

# DMARC policy for the apex domain (monitoring only, p=none)
resource "aws_route53_record" "apex_dmarc" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "_dmarc.operationcode.org"
  type    = "TXT"
  ttl     = 60
  records = ["v=DMARC1; p=none;"]
}

# ======================================================================
# Email: SES for coders.operationcode.org
# ======================================================================

# MX record for SES email receiving
resource "aws_route53_record" "coders_mx" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "coders.operationcode.org"
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.us-east-1.amazonaws.com"]
}

# SPF record for email authentication
resource "aws_route53_record" "coders_spf" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "coders.operationcode.org"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=spf1 include:amazonses.com ~all",
    "anthropic-domain-verification-59rpeq=AndztPpfh6dzVbbixaTcxhWXS",
  ]
}

# DKIM records (3 tokens from SES)
resource "aws_route53_record" "coders_dkim" {
  count   = 3
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "${module.ses_email_forwarder.ses_dkim_tokens[count.index]}._domainkey.coders.operationcode.org"
  type    = "CNAME"
  ttl     = 300
  records = ["${module.ses_email_forwarder.ses_dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# Custom MAIL FROM domain - MX record
resource "aws_route53_record" "coders_bounce_mx" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "bounce.coders.operationcode.org"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}

# Custom MAIL FROM domain - SPF record
resource "aws_route53_record" "coders_bounce_spf" {
  zone_id = aws_route53_zone.operationcode.zone_id
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
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "_dmarc.coders.operationcode.org"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=quarantine; adkim=r; aspf=r; pct=100"]
}

# ======================================================================
# Verification TXT
# ======================================================================

# Legacy Vercel (ZEIT Now) domain verification. INVESTIGATE: likely safe to delete
resource "aws_route53_record" "vercel_now_verification" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "_now.operationcode.org"
  type    = "TXT"
  ttl     = 3600
  records = ["Qmd8XawRvuECtFLQm8SytbgcW2PV2jthtfMy7ujLnTN2gL"]
}

# ======================================================================
# ACM validation
# ======================================================================

# ACM DNS validation for the in-use wildcard certificate (us-east-2, ALB)
resource "aws_route53_record" "acm_validation_apex" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "_62bdef8daffb0b85a77bd7a7c4be6e36.operationcode.org"
  type    = "CNAME"
  ttl     = 300
  records = ["_b1d3619a779f40c956b5f204733bbf79.acm-validations.aws"]
}

# ACM DNS validation for *.staging (same in-use wildcard certificate)
resource "aws_route53_record" "acm_validation_staging" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "_38e269ddbc8fefe222fbb84bdd604ea1.staging.operationcode.org"
  type    = "CNAME"
  ttl     = 300
  records = ["_cacb57a7608af0dcc34e1c19cef298f1.vhzmpjdqfx.acm-validations.aws."]
}

# ======================================================================
# Third-party mail senders (Mailchimp, Mandrill, SendGrid)
# ======================================================================

# Mailchimp DKIM. Used by code (mailchimp3 in the back-end). INVESTIGATE: confirm the Mailchimp account is active
resource "aws_route53_record" "mailchimp_dkim_k2" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "k2._domainkey.operationcode.org"
  type    = "CNAME"
  ttl     = 60
  records = ["dkim2.mcsv.net"]
}

# Mailchimp DKIM. Used by code (mailchimp3 in the back-end). INVESTIGATE: confirm the Mailchimp account is active
resource "aws_route53_record" "mailchimp_dkim_k3" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "k3._domainkey.operationcode.org"
  type    = "CNAME"
  ttl     = 60
  records = ["dkim3.mcsv.net"]
}

# Mandrill DKIM (1024-bit key). Live: production Django mail sends through Mandrill. Keep
resource "aws_route53_record" "mandrill_dkim" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "mandrill._domainkey.operationcode.org"
  type    = "TXT"
  ttl     = 3600
  records = ["v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCrLHiExVd55zd/IQ/J/mRwSRMAocV/hMB3jXwaHH36d9NaVynQFYV8NaWi69c1veUtRzGt7yAioXqLj7Z4TeEUoOLgrKsn8YnckGs9i3B3tVFB+Ch/4mPhXWiNfNdynHWBcPcbJ8kjEQ2U8y78dHZj1YeRXXVvWob2OaKynO8/lQIDAQAB;"]
}

# SendGrid account 5672389 link/open tracking. INVESTIGATE: confirm account is active
resource "aws_route53_record" "sendgrid_link_tracking" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "5672389.operationcode.org"
  type    = "CNAME"
  ttl     = 3600
  records = ["sendgrid.net."]
}

# SendGrid DKIM. INVESTIGATE: confirm account is active
resource "aws_route53_record" "sendgrid_dkim_s1" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "s1._domainkey.operationcode.org"
  type    = "CNAME"
  ttl     = 3600
  records = ["s1.domainkey.u5672389.wl140.sendgrid.net."]
}

# SendGrid DKIM. INVESTIGATE: confirm account is active
resource "aws_route53_record" "sendgrid_dkim_s2" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "s2._domainkey.operationcode.org"
  type    = "CNAME"
  ttl     = 3600
  records = ["s2.domainkey.u5672389.wl140.sendgrid.net."]
}

# SendGrid link branding. INVESTIGATE: confirm account is active
resource "aws_route53_record" "sendgrid_notify_link" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "link.notify.operationcode.org"
  type    = "CNAME"
  ttl     = 3600
  records = ["sendgrid.net."]
}

# SendGrid return-path. INVESTIGATE: confirm account is active
resource "aws_route53_record" "sendgrid_notify_mail" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "mail.notify.operationcode.org"
  type    = "CNAME"
  ttl     = 3600
  records = ["u5672389.wl140.sendgrid.net."]
}

# SendGrid sending IP. INVESTIGATE: confirm account is active
resource "aws_route53_record" "sendgrid_notify_o1" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "o1.notify.operationcode.org"
  type    = "A"
  ttl     = 3600
  records = ["168.245.5.176"]
}

# ======================================================================
# Legacy hosts (services, DigitalOcean, Cloudways)
# ======================================================================

# DigitalOcean community host. INVESTIGATE: live server (SSH answers); find its owner before deletion.
resource "aws_route53_record" "community_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "community.operationcode.org"
  type    = "A"
  ttl     = 600
  records = ["192.241.185.68"]
}

# Cloudways host for services (unknown app). INVESTIGATE: check Cloudways account
resource "aws_route53_record" "services_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "services.operationcode.org"
  type    = "A"
  ttl     = 60
  records = ["174.138.92.215"]
}

# DigitalOcean NFS host. INVESTIGATE: likely dead
resource "aws_route53_record" "services_nfs_a" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "nfs.services.operationcode.org"
  type    = "A"
  ttl     = 60
  records = ["138.197.94.99"]
}

# Kibana on the services host. INVESTIGATE: likely dead
resource "aws_route53_record" "kibana" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "kibana.operationcode.org"
  type    = "CNAME"
  ttl     = 60
  records = ["services.operationcode.org."]
}

# Mautic on the services host. INVESTIGATE: likely dead
resource "aws_route53_record" "mautic" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "mautic.operationcode.org"
  type    = "CNAME"
  ttl     = 60
  records = ["services.operationcode.org."]
}

# Slack slash commands on the services host. INVESTIGATE: check Slack app request URLs
resource "aws_route53_record" "slash_commands" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "slash-commands.operationcode.org"
  type    = "CNAME"
  ttl     = 60
  records = ["services.operationcode.org."]
}

# Test host on the services host. INVESTIGATE: check Cloudways account
resource "aws_route53_record" "test" {
  zone_id = aws_route53_zone.operationcode.zone_id
  name    = "test.operationcode.org"
  type    = "CNAME"
  ttl     = 60
  records = ["services.operationcode.org."]
}

# ======================================================================
# Import blocks for operationcode.org (zone and pre-existing records).
# They can be removed after the first successful apply.
# ======================================================================

import {
  to = aws_route53_zone.operationcode
  id = "Z08173331NAK6ZJUBZENQ"
}

import {
  to = aws_route53_record.apex_a
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_A"
}

import {
  to = aws_route53_record.apex_caa
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_CAA"
}

import {
  to = aws_route53_record.apex_mx
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_MX"
}

import {
  to = aws_route53_record.apex_txt
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_TXT"
}

import {
  to = aws_route53_record.sendgrid_link_tracking
  id = "Z08173331NAK6ZJUBZENQ_5672389.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.acm_validation_apex
  id = "Z08173331NAK6ZJUBZENQ__62bdef8daffb0b85a77bd7a7c4be6e36.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.apex_dmarc
  id = "Z08173331NAK6ZJUBZENQ__dmarc.operationcode.org_TXT"
}

import {
  to = aws_route53_record.mailchimp_dkim_k2
  id = "Z08173331NAK6ZJUBZENQ_k2._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.mailchimp_dkim_k3
  id = "Z08173331NAK6ZJUBZENQ_k3._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.mandrill_dkim
  id = "Z08173331NAK6ZJUBZENQ_mandrill._domainkey.operationcode.org_TXT"
}

import {
  to = aws_route53_record.sendgrid_dkim_s1
  id = "Z08173331NAK6ZJUBZENQ_s1._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_dkim_s2
  id = "Z08173331NAK6ZJUBZENQ_s2._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.vercel_now_verification
  id = "Z08173331NAK6ZJUBZENQ__now.operationcode.org_TXT"
}

import {
  to = aws_route53_record.api_a
  id = "Z08173331NAK6ZJUBZENQ_api.operationcode.org_A"
}

import {
  to = aws_route53_record.api_aaaa
  id = "Z08173331NAK6ZJUBZENQ_api.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.community_a
  id = "Z08173331NAK6ZJUBZENQ_community.operationcode.org_A"
}

import {
  to = aws_route53_record.kibana
  id = "Z08173331NAK6ZJUBZENQ_kibana.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.mautic
  id = "Z08173331NAK6ZJUBZENQ_mautic.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_notify_link
  id = "Z08173331NAK6ZJUBZENQ_link.notify.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_notify_mail
  id = "Z08173331NAK6ZJUBZENQ_mail.notify.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_notify_o1
  id = "Z08173331NAK6ZJUBZENQ_o1.notify.operationcode.org_A"
}

import {
  to = aws_route53_record.pybot_a
  id = "Z08173331NAK6ZJUBZENQ_pybot.operationcode.org_A"
}

import {
  to = aws_route53_record.pybot_aaaa
  id = "Z08173331NAK6ZJUBZENQ_pybot.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.resources_a
  id = "Z08173331NAK6ZJUBZENQ_resources.operationcode.org_A"
}

import {
  to = aws_route53_record.resources_aaaa
  id = "Z08173331NAK6ZJUBZENQ_resources.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.services_a
  id = "Z08173331NAK6ZJUBZENQ_services.operationcode.org_A"
}

import {
  to = aws_route53_record.services_nfs_a
  id = "Z08173331NAK6ZJUBZENQ_nfs.services.operationcode.org_A"
}

import {
  to = aws_route53_record.slash_commands
  id = "Z08173331NAK6ZJUBZENQ_slash-commands.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.acm_validation_staging
  id = "Z08173331NAK6ZJUBZENQ__38e269ddbc8fefe222fbb84bdd604ea1.staging.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.api_staging_a
  id = "Z08173331NAK6ZJUBZENQ_api.staging.operationcode.org_A"
}

import {
  to = aws_route53_record.api_staging_aaaa
  id = "Z08173331NAK6ZJUBZENQ_api.staging.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.storybook
  id = "Z08173331NAK6ZJUBZENQ_storybook.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.test
  id = "Z08173331NAK6ZJUBZENQ_test.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.www_a
  id = "Z08173331NAK6ZJUBZENQ_www.operationcode.org_A"
}
