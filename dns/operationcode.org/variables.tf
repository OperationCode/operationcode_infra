variable "hosted-zone" {
  description = "Hosted zone"
  type        = "string"
}

variable "k8s-cluster-ingress" {
  description = "Load balancer URL for the Kubernetes ingress"
  type = "string"
}

variable "pybot-lb-ingress" {
  description = "Load balancer URL for pybot subdomain ingress"
  type = "string"
}