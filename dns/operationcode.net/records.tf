resource "dnsimple_record" "root" {
  domain = "${var.dnsimple_domain}"
  name   = ""
  type   = "URL"
  value  = "https://operationcode.org"
}

resource "dnsimple_record" "www" {
  domain = "${var.dnsimple_domain}"
  name   = "www"
  type   = "URL"
  value  = "https://operationcode.org"
}
