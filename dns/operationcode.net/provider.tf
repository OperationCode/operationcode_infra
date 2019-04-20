/*
credentials sourced from DNSIMPLE_TOKEN and DNSIMPLE_ACCOUNT vars
*/
provider "dnsimple" {}

terraform {
  backend "s3" {}
}
