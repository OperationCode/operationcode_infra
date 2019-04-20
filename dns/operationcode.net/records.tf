resource "dnsimple_record" "root" {
  domain = "${var.hosted-zone}"
  name   = ""
  type   = "URL"
  value  = "https://operationcode.org"
}

resource "dnsimple_record" "www" {
  domain = "${var.hosted-zone}"
  name   = "www"
  type   = "URL"
  value  = "https://operationcode.org"
}
