# Dev Cluster values stored in the AWS SSM Parameter Store
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

provider "kubectl" {
  load_config_file       = true
}

data "aws_ssm_parameter" "gitops_dev_argocd_authCA" {
  name = "/gitops/dev-argocdca"
}

data "aws_ssm_parameter" "gitops_dev_argocd_authN" {
  name = "/gitops/dev-argocd-token"
}

data "aws_ssm_parameter" "gitops_dev_argocd_serverurl" {
  name = "/gitops/dev-serverurl"
}

locals {
    tls_data = jsonencode(
    {
        "bearerToken": "${data.aws_ssm_parameter.gitops_dev_argocd_authN.value}",
        "tlsClientConfig": { "insecure": false, "caData": base64encode("${data.aws_ssm_parameter.gitops_dev_argocd_authCA.value}")}
    })
}

resource "kubectl_manifest" "argocd_dev_cluster-connect" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: dev-cluster-argo-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  config: |
    ${local.tls_data}
  name: "dev-cluster"
  server: "${data.aws_ssm_parameter.gitops_dev_argocd_serverurl.value}"
YAML
}

