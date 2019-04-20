resource "dnsimple_record" "root" {
  domain = "${var.dnsimple-domain}"
  name   = ""
  type   = "URL"
  value  = "https://operationcode.org"
}

resource "dnsimple_record" "www" {
  domain = "${var.dnsimple-domain}"
  name   = "www"
  type   = "URL"
  value  = "https://operationcode.org"
}

resource "dnsimple_record" "api" {
  domain = "${var.dnsimple-domain}"
  name = "api"
  type = "CNAME"
  value = "${var.k8s-cluster-ingress}"
}

resource "dnsimple_record" "staging_api" {
  domain = "${var.dnsimple-domain}"
  name = "api.staging"
  type = "CNAME"
  value = "${var.k8s-cluster-ingress}"
}