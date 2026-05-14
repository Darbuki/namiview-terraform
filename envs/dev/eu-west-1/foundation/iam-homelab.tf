data "aws_caller_identity" "current" {}

resource "aws_iam_user" "homelab_dev" {
  name = "namiview-homelab-dev"
  path = "/"
}

resource "aws_iam_access_key" "homelab_dev" {
  user = aws_iam_user.homelab_dev.name
}

resource "aws_secretsmanager_secret" "homelab_dev_credentials" {
  name        = "namiview-prod/homelab-dev-credentials"
  description = "AWS access key + secret for the namiview-homelab-dev IAM user. Bootstrap source for the k8s aws-credentials secret in the namiview-dev namespace."
}

resource "aws_secretsmanager_secret_version" "homelab_dev_credentials" {
  secret_id = aws_secretsmanager_secret.homelab_dev_credentials.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.homelab_dev.id
    secret_access_key = aws_iam_access_key.homelab_dev.secret
  })
}

resource "aws_iam_user_policy" "homelab_dev" {
  name = "namiview-homelab-dev"
  user = aws_iam_user.homelab_dev.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadWriteDevBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:HeadBucket",
        ]
        Resource = [
          aws_s3_bucket.namiview-dev-bucket.arn,
          "${aws_s3_bucket.namiview-dev-bucket.arn}/*",
        ]
      },
      {
        Sid    = "SQSDevJobs"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
        ]
        Resource = [
          aws_sqs_queue.jobs.arn,
          aws_sqs_queue.jobs_dlq.arn,
        ]
      },
      # Dev workloads still consume secrets prefixed namiview-prod/* (no separate dev SM tree).
      {
        Sid    = "SecretsManagerReadProd"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:namiview-prod/*"
      },
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
        ]
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/*"
      },
    ]
  })
}
