resource "aws_sqs_queue" "jobs_dlq" {
  name                      = "${var.cluster_name}-jobs-dlq"
  message_retention_seconds = 1209600 # 14d
}

resource "aws_sqs_queue" "jobs" {
  name                       = "${var.cluster_name}-jobs"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600 # 4d

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "namiview" {
  bucket = aws_s3_bucket.namiview-prod-bucket.id

  rule {
    id     = "expire-pending"
    status = "Enabled"
    filter { prefix = "pending/" }
    expiration { days = 1 }
  }
}

resource "aws_iam_role_policy" "api_jobs_access" {
  name = "jobs-access"
  role = module.api_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
      ]
      Resource = aws_sqs_queue.jobs.arn
    }]
  })
}

module "worker_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-namiview-worker"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["namiview:namiview-worker"]
    }
  }
}

resource "aws_iam_role_policy" "worker_sqs_access" {
  name = "sqs-access"
  role = module.worker_irsa.iam_role_name

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
      Resource = aws_sqs_queue.jobs.arn
    }]
  })
}

resource "aws_iam_role_policy" "worker_s3_access" {
  name = "s3-access"
  role = module.worker_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
      ]
      Resource = "${aws_s3_bucket.namiview-prod-bucket.arn}/pending/*"
    }]
  })
}
