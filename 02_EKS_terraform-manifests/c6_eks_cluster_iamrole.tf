# ------------------------------------------------------------------------------
# IAM Role for EKS Control Plane
# This role is assumed by the EKS service to manage the control plane resources
# ------------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster" {
  # Unique name for the control plane IAM role
  name = "${local.name}-eks-cluster-role"

  # Trust policy to allow EKS to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  # Tags applied to this IAM role
  tags = var.tags
}

# ------------------------------------------------------------------------------
# Attach the required policy for EKS to manage cluster control plane
# This is mandatory for all EKS clusters
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ------------------------------------------------------------------------------
# Attach VPC Resource Controller policy
# Required for advanced networking, Fargate, and Karpenter support
# Recommended to include by default for production-grade EKS
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}



# resource "aws_iam_role" "s3_readOnly_role" {
#   name = "s3_readOnly_role"

#   # Terraform's "jsonencode" function converts a
#   # Terraform expression result to valid JSON syntax.
#   assume_role_policy = jsonencode({
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Principal": {
#                 "Service": "pods.eks.amazonaws.com"
#             },
#             "Action": [
#                 "sts:AssumeRole",
#                 "sts:TagSession"
#             ]
#         }
#     ]
# })

# }


# resource "aws_iam_role_policy_attachment" "s3_readOnly_policy" {
#   role=aws_iam_role.s3_readOnly_role.name
#   policy_arn="arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }


# resource "aws_eks_addon" "pod_identity_agent" {
#   cluster_name  = aws_eks_cluster.main.name
#   addon_name    = "eks-pod-identity-agent"
#   addon_version = "v1.3.7-eksbuild.2"  # use latest compatible version
# }


# resource "aws_eks_pod_identity_association" "s3_access" {
#   cluster_name    = aws_eks_cluster.main.name
#   namespace       = "default"
#   service_account = "aws-cli-sa"
#   role_arn        = aws_iam_role.s3_readOnly_role.arn

#   depends_on=[
#     aws_eks_addon.pod_identity_agent
#   ]
# }



# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}



# resource "aws_iam_role" "get_secrets_role" {
#   name = "secrets_role"

#   # Terraform's "jsonencode" function converts a
#   # Terraform expression result to valid JSON syntax.
#   assume_role_policy = jsonencode({
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "pods.eks.amazonaws.com"
#       },
#       "Action": [
#         "sts:AssumeRole",
#         "sts:TagSession"
#       ]
#     }
#   ]
# }) 
# }

# resource "aws_iam_policy" "read_secret_policy" {
#   name        = "catalog-db-secret-policy"


#   # Terraform's "jsonencode" function converts a
#   # Terraform expression result to valid JSON syntax.
#   policy = jsonencode({
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": [
#         "secretsmanager:GetSecretValue",
#         "secretsmanager:DescribeSecret"
#       ],
#       "Resource": "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:catalog-db-secret*"
#     }
#   ]
# })
# }


# resource "aws_iam_policy_attachment" "read_secrets_policy" {
#   name="read_secrets_policy_attachment"
#   roles=[aws_iam_role.get_secrets_role.name]
#   policy_arn = aws_iam_policy.read_secret_policy.arn
# }

# resource "aws_eks_pod_identity_association" "get_secrets" {
#   cluster_name    = aws_eks_cluster.main.name
#   namespace       = "default"
#   service_account = "catalog-mysql-sa"
#   role_arn        = aws_iam_role.get_secrets_role.arn

#     depends_on=[
#     aws_eks_addon.pod_identity_agent
#   ]
# }




