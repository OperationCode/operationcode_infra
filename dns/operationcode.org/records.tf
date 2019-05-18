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
