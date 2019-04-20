variable "dnsimple-domain" {
  description = "Hosted zone"
  type        = "string"
}

variable "k8s-cluster-ingress" {
  description = "Load balancer URL for the Kubernetes ingress"
  type = "string"
}