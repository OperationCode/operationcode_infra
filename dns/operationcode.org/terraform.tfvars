terragrunt = {
  include {
    path = "${find_in_parent_folders()}"
  }
}

dnsimple_domain = "operationcode.org"
k8s-cluster-ingress = "ac206d147f3ed11e7a802062a4d50822-1344197385.us-east-2.elb.amazonaws.com"
