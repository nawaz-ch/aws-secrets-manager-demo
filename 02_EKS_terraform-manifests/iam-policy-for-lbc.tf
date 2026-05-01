resource "aws_iam_policy" "lb_controller_policy" {
  name        = "lb-controller-policy"
  path        = "/"
  description = "My test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy =data.http.lbc_iam_policy.response_body
}


resource "aws_iam_role" "lbc_controller_role" {
  name = "lbc_controller_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version":"2012-10-17",		 	 	 
    "Statement": [
        {
            "Sid": "AllowEksAuthToAssumeRoleForPodIdentity",
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
})

}

resource "aws_iam_role_policy_attachment" "lbc_contoller_policy_attach" {
  role       = aws_iam_role.lbc_controller_role.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn
}

resource "aws_eks_pod_identity_association" "use_elastic_loadbalancer" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc_controller_role.arn

  depends_on=[
    aws_eks_addon.pod_identity_agent
  ]
}