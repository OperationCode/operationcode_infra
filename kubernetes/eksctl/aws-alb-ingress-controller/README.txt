
# Recreating the ALB ingress controller

installed using:
```bash
helm install \
  aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=operationcode-backend \
  --set enableCertManager=false \
  --set serviceAccount.create=false \
  --set serviceAccount.name=alb-ingress-controller
```

to upgrade, do that with `helm upgrade` plus the above flags
