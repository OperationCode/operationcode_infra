resource "dnsimple_record" "www" {
  domain = "${var.hosted-zone}"
  name = "_now"
  type = "TXT"
  value = "Qmd8XawRvuECtFLQm8SytbgcW2PV2jthtfMy7ujLnTN2gL"
}

resource "dnsimple_record" "www" {
  domain = "${var.hosted-zone}"
  name = ""
  type = "CNAME"
  value = "alias.zeit.co"
}

resource "dnsimple_record" "api" {
  domain = "${var.hosted-zone}"
  name = "api"
  type = "CNAME"
  value = "${var.k8s-cluster-ingress}"
}

resource "dnsimple_record" "staging_api" {
  domain = "${var.hosted-zone}"
  name = "api.staging"
  type = "CNAME"
  value = "${var.k8s-cluster-ingress}"
}

resource "dnsimple_record" "dashboards" {
  domain = "${var.hosted-zone}"
  name = "dashboards"
  type = "CNAME"
  value = "${var.k8s-cluster-ingress}"
}

resource "dnsimple_record" "pybot" {
  domain = "${var.hosted-zone}"
  name = "pybot"
  type = "CNAME"
  value = "${var.pybot-lb-ingress}"
}

resource "dnsimple_record" "staging_pybot" {
  domain = "${var.hosted-zone}"
  name = "pybot.staging"
  type = "CNAME"
  value = "${var.pybot-lb-ingress}"
}

resource "dnsimple_record" "staging_pybot_cert_verification" {
  domain = "${var.hosted-zone}"
  name = "_69b5c7278c7c13092899e1b67e8de6c1.pybot.staging"
  type = "CNAME"
  value = "_9fdd906cbd86d545894523f8cd809812.ltfvzjuylp.acm-validations.aws"
}

resource "dnsimple_record" "resources_api" {
  domain = "${var.hosted-zone}"
  name = "resources"
  type = "CNAME"
  value = "${var.k8s-cluster-ingress}"
}

resource "dnsimple_record" "resources_staging_api" {
  domain = "${var.hosted-zone}"
  name = "resources.staging"
  type = "CNAME"
  value = "${var.k8s-cluster-ingress}"
}
