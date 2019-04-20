terragrunt = {
  include {
    path = "${find_in_parent_folders()}"
  }
}

dnsimple_domain = "operationcode.net"