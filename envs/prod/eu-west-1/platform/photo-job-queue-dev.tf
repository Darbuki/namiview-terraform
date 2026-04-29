data "aws_s3_bucket" "namiview_dev_bucket" {
  bucket = "namiview-dev-bucket"
}

resource "aws_sqs_queue" "jobs_dlq_dev" {
  name                      = "${var.cluster_name}-dev-jobs-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "jobs_dev" {
  name                       = "${var.cluster_name}-dev-jobs"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq_dev.arn
    maxReceiveCount     = 3
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "namiview_dev" {
  bucket = data.aws_s3_bucket.namiview_dev_bucket.id

  rule {
    id     = "expire-pending"
    status = "Enabled"
    filter {
      prefix = "pending/"
    }
    expiration {
      days = 1
    }
  }
}

module "api_irsa_dev" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-namiview-api-dev"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["namiview-dev:namiview-api"]
    }
  }
}

resource "aws_iam_role_policy" "api_dev_s3_access" {
  name = "s3-access"
  role = module.api_irsa_dev.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:HeadBucket",
      ]
      Resource = [
        data.aws_s3_bucket.namiview_dev_bucket.arn,
        "${data.aws_s3_bucket.namiview_dev_bucket.arn}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "api_dev_jobs_access" {
  name = "jobs-access"
  role = module.api_irsa_dev.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
      ]
      Resource = aws_sqs_queue.jobs_dev.arn
    }]
  })
}

module "worker_irsa_dev" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-namiview-worker-dev"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["namiview-dev:namiview-worker"]
    }
  }
}

resource "aws_iam_role_policy" "worker_dev_sqs_access" {
  name = "sqs-access"
  role = module.worker_irsa_dev.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
      ]
      Resource = aws_sqs_queue.jobs_dev.arn
    }]
  })
}

resource "aws_iam_role_policy" "worker_dev_s3_access" {
  name = "s3-access"
  role = module.worker_irsa_dev.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${data.aws_s3_bucket.namiview_dev_bucket.arn}/pending/*"
    }]
  })
}
