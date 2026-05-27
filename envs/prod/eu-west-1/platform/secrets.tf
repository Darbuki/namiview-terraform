# AWS Secrets Manager — populate manually after first apply
#
# Only EKS-only secrets live here. Shared workload secrets (jwt,
# google-creds, mongodb, grafana) moved to the foundation layer
# (envs/prod/eu-west-1/foundation/secrets-shared.tf) so they survive
# EKS teardown — the homelab consumes them via ExternalSecrets.
resource "aws_secretsmanager_secret" "dockerhub" {
  name        = "${var.cluster_name}/dockerhub"
  description = "DockerHub credentials for image pulls"
}

resource "aws_secretsmanager_secret" "arc_github_token" {
  name        = "${var.cluster_name}/arc-github-token"
  description = "GitHub PAT for Actions Runner Controller"
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
          aws_secretsmanager_secret.arc_github_token.arn,
          # Foundation-layer secrets (managed in envs/prod/eu-west-1/foundation/).
          # Referenced by ARN name pattern instead of remote_state to keep
          # the two layers decoupled — the contract is the secret name.
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/jwt-*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/google-creds-*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/mongodb-*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/grafana-*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/anthropic-api-key-*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/triage-agent-github-pat-*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/tailscale-operator-oauth-*"
        ]
      }
    ]
  })
}
