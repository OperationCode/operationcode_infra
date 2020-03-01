resource "dnsimple_record" "root" {
  domain = "${var.hosted-zone}"
  name   = ""
  type   = "ALIAS"
  value  = "alias.zeit.co"
  ttl    = 60
}

resource "dnsimple_record" "www" {
  domain = "${var.hosted-zone}"
  name   = "www"
  type   = "ALIAS"
  value  = "alias.zeit.co"
  ttl    = 60
}

resource "dnsimple_record" "www_txt" {
  domain = "${var.hosted-zone}"
  name   = "_now"
  type   = "TXT"
  value  = "Qmd8XawRvuECtFLQm8SytbgcW2PV2jthtfMy7ujLnTN2gL"
}

resource "dnsimple_record" "api" {
  domain = "${var.hosted-zone}"
  name   = "api"
  type   = "CNAME"
  value  = "backend.k8s.operationcode.org"
}

resource "dnsimple_record" "staging_api" {
  domain = "${var.hosted-zone}"
  name   = "api.staging"
  type   = "CNAME"
  value  = "backend-staging.k8s.operationcode.org"
}

resource "dnsimple_record" "pybot" {
  domain = "${var.hosted-zone}"
  name   = "pybot"
  type   = "CNAME"
  value  = "${var.pybot-lb-ingress}"
}

resource "dnsimple_record" "staging_pybot" {
  domain = "${var.hosted-zone}"
  name   = "pybot.staging"
  type   = "CNAME"
  value  = "${var.pybot-lb-ingress}"
}

resource "dnsimple_record" "staging_pybot_cert_verification" {
  domain = "${var.hosted-zone}"
  name   = "_69b5c7278c7c13092899e1b67e8de6c1.pybot.staging"
  type   = "CNAME"
  value  = "_9fdd906cbd86d545894523f8cd809812.ltfvzjuylp.acm-validations.aws"
}

resource "dnsimple_record" "resources_api" {
  domain = "${var.hosted-zone}"
  name   = "resources"
  type   = "CNAME"
  value  = "resources.k8s.operationcode.org"
}

resource "dnsimple_record" "resources_staging_api" {
  domain = "${var.hosted-zone}"
  name   = "resources.staging"
  type   = "CNAME"
  value  = "resources-staging.k8s.operationcode.org"
}
