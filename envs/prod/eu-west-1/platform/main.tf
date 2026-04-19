data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "namiview-prod-bucket" {
  bucket = "namiview-prod-bucket"
}

# Block all public access — belt-and-suspenders guard
resource "aws_s3_bucket_public_access_block" "namiview" {
  bucket = aws_s3_bucket.namiview-prod-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt at rest with SSE-S3 (free, no KMS key required)
resource "aws_s3_bucket_server_side_encryption_configuration" "namiview" {
  bucket = aws_s3_bucket.namiview-prod-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Gateway VPC Endpoint — free, keeps S3 traffic off the internet
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = module.vpc.private_route_table_ids
}

# IRSA role for namiview API to access S3
module "api_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-namiview-api"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["namiview:namiview-api"]
    }
  }
}

resource "aws_iam_role_policy" "api_s3_access" {
  name = "s3-access"
  role = module.api_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:HeadBucket"
        ]
        Resource = [
          aws_s3_bucket.namiview-prod-bucket.arn,
          "${aws_s3_bucket.namiview-prod-bucket.arn}/*"
        ]
      }
    ]
  })
}