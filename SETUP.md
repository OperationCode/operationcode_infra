# Operation Code's Kubernetes Cluster.

Greetings! Much of Operation Code's web site runs in a [Kubernetes](https://kubernetes.io/) cluster.  These instructions will guide you through setting up access to our cluster so you can run rails console, tail logs, and more!

# Getting access to the cluster

1. Ensure you have AWS access, and the aws CLI is operating correctly
2. Install eksctl: https://eksctl.io/introduction/#installation
3. Run: `eksctl utils write-kubeconfig --region us-east-2 --cluster operationcode-backend`
4. Verify everything works: `kubectl get namespaces`
