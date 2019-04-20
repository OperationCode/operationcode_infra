terragrunt = {
  include {
    path = "${find_in_parent_folders()}"
  }
}

hosted-zone = "operationcode.net"