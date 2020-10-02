<div align="center">
  <a href="https://operationcode.org" height="750" width="750">
    <img
      alt="Operation Code Hacktoberfest Banner"
      src="https://operation-code-assets.s3.us-east-2.amazonaws.com/operationcode_hacktoberfest_2020.jpg"
    >
  </a>
</div>
<br />
<br />

# 🎃 Hacktoberfest 🎃	

[All the details you need](https://github.com/OperationCode/START_HERE/blob/master/README.md#-hacktoberfest-) before participating with us during Hacktoberfest.	

<br />

# Operation Code Infra
Platform infrastructure for the [Operation Code site](https://operationcode.org/).

[![CircleCI](https://circleci.com/gh/OperationCode/operationcode_infra/tree/master.svg?style=svg)](https://circleci.com/gh/OperationCode/operationcode_infra/tree/master)

## warning

This repository is using [ArgoCD](https://argoproj.github.io/argo-cd/) to deploy the Operation Code infrastructure. Changes landed on main in this repository are reflected in the real running infrastructure.

To set up your workstation to access our Kubernetes cluster, please check the below instructions

## Setup

### Operation Code's Kubernetes Cluster.
Greetings! Much of Operation Code's web site runs in a [Kubernetes](https://kubernetes.io/) cluster.  These instructions will guide you through setting up access to our cluster so you can run rails console, tail logs, and more!   

### Getting access to the cluster
1. Ensure you have [AWS](https://aws.amazon.com) access, and the [aws CLI](https://aws.amazon.com/cli/) is operating correctly
2. Install eksctl: https://eksctl.io/introduction/#installation
3. Run: `eksctl utils write-kubeconfig --region us-east-2 --cluster operationcode-backend`
4. Verify everything works: `kubectl get namespaces`


## Licensing
 [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)   
Operation Code Infra is under the [MIT License](/LICENSE).
