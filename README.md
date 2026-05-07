# AWS Secrets Manager Driver setup

install the Secrets Store CSI Driver and the AWS Secrets and Configuration Provider (ASCP) on EKS cluster. This setup enables Kubernetes Pods to securely retrieve secrets from AWS Secrets Manager and AWS Systems Manager Parameter Store, using EKS Pod Identity for authentication without storing any credentials inside the cluster.

**Architecture Diagram**
