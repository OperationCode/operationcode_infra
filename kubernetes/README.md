# Setup

To re-create a cluster, everything you need is in the eksctl/ folder.  Use eksctl with the `operationcode-backend.yaml` config file to create the cluster.
Then install the controllers:
* aws-alb-ingress-controller
* external-dns
* vertical-pod-autoscaler

