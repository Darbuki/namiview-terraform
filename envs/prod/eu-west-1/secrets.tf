# AWS Secrets Manager — populate manually after first apply
resource "aws_secretsmanager_secret" "dockerhub" {
  name        = "${var.cluster_name}/dockerhub"
  description = "DockerHub credentials for image pulls"
}

resource "aws_secretsmanager_secret" "namiview_app" {
  name        = "${var.cluster_name}/namiview-app"
  description = "Namiview application secrets (API keys, DB connection strings, etc.)"
}

# IRSA role for External Secrets Operator
module "eso_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-external-secrets"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}

# IAM policy for ESO to read secrets
resource "aws_iam_role_policy" "eso_secrets_access" {
  name = "secrets-access"
  role = module.eso_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          aws_secretsmanager_secret.dockerhub.arn,
          aws_secretsmanager_secret.namiview_app.arn
        ]
      }
    ]
  })
}
