resource "kubernetes_namespace" "external_secrets" {
  metadata { name = "external-secrets" }
}

resource "kubernetes_namespace" "namiview" {
  metadata { name = "namiview" }
}

resource "kubernetes_namespace" "namiview_dev" {
  metadata { name = "namiview-dev" }
}

resource "kubernetes_namespace" "argocd" {
  metadata { name = local.argocd_namespace }
}

data "aws_secretsmanager_secret_version" "homelab_prod_credentials" {
  secret_id = "namiview-prod/homelab-credentials"
}

data "aws_secretsmanager_secret_version" "homelab_dev_credentials" {
  secret_id = "namiview-prod/homelab-dev-credentials"
}

locals {
  homelab_prod_creds = jsondecode(data.aws_secretsmanager_secret_version.homelab_prod_credentials.secret_string)
  homelab_dev_creds  = jsondecode(data.aws_secretsmanager_secret_version.homelab_dev_credentials.secret_string)
}

# Bootstrap secret consumed by ESO ClusterSecretStore (cluster-wide auth to SM).
resource "kubernetes_secret" "aws_credentials_eso" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }
  data = {
    "access-key-id"     = local.homelab_prod_creds.access_key_id
    "secret-access-key" = local.homelab_prod_creds.secret_access_key
  }
  type = "Opaque"
}

# Mounted by prod app pods for direct S3/SQS access.
resource "kubernetes_secret" "aws_credentials_prod" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.namiview.metadata[0].name
  }
  data = {
    "access-key-id"     = local.homelab_prod_creds.access_key_id
    "secret-access-key" = local.homelab_prod_creds.secret_access_key
  }
  type = "Opaque"
}

# Mounted by dev app pods.
resource "kubernetes_secret" "aws_credentials_dev" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.namiview_dev.metadata[0].name
  }
  data = {
    "access-key-id"     = local.homelab_dev_creds.access_key_id
    "secret-access-key" = local.homelab_dev_creds.secret_access_key
  }
  type = "Opaque"
}
