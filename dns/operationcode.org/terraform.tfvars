terragrunt = {
  include {
    path = "${find_in_parent_folders()}"
  }
}

hosted-zone = "operationcode.org"
k8s-cluster-ingress = "ac206d147f3ed11e7a802062a4d50822-1344197385.us-east-2.elb.amazonaws.com"
pybot-lb-ingress = "pyback-lb-197482116.us-east-2.elb.amazonaws.com"