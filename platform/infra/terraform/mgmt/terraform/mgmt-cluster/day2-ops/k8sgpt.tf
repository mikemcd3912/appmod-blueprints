# Create IAM role for k8sgpt to access Bedrock
resource "aws_iam_role" "k8sgpt_bedrock_role" {
  name = "k8sgpt-bedrock-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "${data.aws_iam_openid_connect_provider.eks_oidc.arn}"
        }
        Condition = {
          StringEquals = {
            "${data.aws_iam_openid_connect_provider.eks_oidc}:sub": "system:serviceaccount:k8sgpt-operator-system:k8sgpt-operator-controller-manager"
            "${data.aws_iam_openid_connect_provider.eks_oidc}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Create IAM policy for Bedrock access
resource "aws_iam_role_policy" "k8sgpt_bedrock_policy" {
  name = "k8sgpt-bedrock-policy"
  role = aws_iam_role.k8sgpt_bedrock_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "kubectl_manifest" "application_argocd_k8sgpt_operator" {
  depends_on = [ resource.k8sgpt_bedrock_role ]
  yaml_body = templatefile("${path.module}/templates/argocd-apps/k8sgpt.yaml", {
     AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
     EKS_REGION = var.region
    }
  )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd application/k8sgpt-operator --timeout=300s"

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy

    command = "kubectl wait --for=delete svc k8sgpt-operator-controller-manager-metrics-service -n k8sgpt-operator-system --timeout=300s"

    interpreter = ["/bin/bash", "-c"]
  }
}