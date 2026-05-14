resource "aws_iam_user" "homelab_prod" {
  name = "namiview-homelab-prod"
  path = "/"
}

resource "aws_iam_access_key" "homelab_prod" {
  user = aws_iam_user.homelab_prod.name
}

resource "aws_secretsmanager_secret" "homelab_prod_credentials" {
  name        = "namiview-prod/homelab-credentials"
  description = "AWS access key + secret for the namiview-homelab-prod IAM user. Bootstrap source for the k8s aws-credentials secret in the homelab cluster."
}

resource "aws_secretsmanager_secret_version" "homelab_prod_credentials" {
  secret_id = aws_secretsmanager_secret.homelab_prod_credentials.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.homelab_prod.id
    secret_access_key = aws_iam_access_key.homelab_prod.secret
  })
}

resource "aws_iam_user_policy" "homelab_prod" {
  name = "namiview-homelab-prod"
  user = aws_iam_user.homelab_prod.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadWriteProdBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:HeadBucket",
        ]
        Resource = [
          aws_s3_bucket.namiview-prod-bucket.arn,
          "${aws_s3_bucket.namiview-prod-bucket.arn}/*",
        ]
      },
      {
        Sid    = "SQSProdJobs"
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
