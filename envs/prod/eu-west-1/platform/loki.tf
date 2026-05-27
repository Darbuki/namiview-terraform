# Loki bucket itself lives in the foundation layer (envs/prod/eu-west-1/foundation/buckets-loki.tf)
# so it survives the EKS teardown. Read it by name to avoid a cross-layer state dependency.
data "aws_s3_bucket" "loki" {
  bucket = "namiview-loki-logs"
}

module "loki_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-loki"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["logging:loki"]
    }
  }
}

resource "aws_iam_role_policy" "loki_s3_access" {
  name = "s3-access"
  role = module.loki_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
        ]
        Resource = data.aws_s3_bucket.loki.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
        ]
        Resource = "${data.aws_s3_bucket.loki.arn}/*"
      }
    ]
  })
}
