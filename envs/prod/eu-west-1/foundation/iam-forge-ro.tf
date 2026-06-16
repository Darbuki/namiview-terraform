# Read-only IAM user for the forge homelab box (where the Claude agent runs), so
# it can inspect AWS directly — ML training runs in s3://namiview-ml, EC2 state,
# quota status, app buckets/queues/metrics — instead of routing every command
# through the user's Mac. namiview-scoped + READ-ONLY: no writes, no deletes, no
# launches, no secret values. The access key is configured manually on forge
# (chmod 600); rotate with `terraform taint aws_iam_access_key.forge_ro`.

resource "aws_iam_user" "forge_ro" {
  name = "namiview-forge-ro"
}

resource "aws_iam_access_key" "forge_ro" {
  user = aws_iam_user.forge_ro.name
}

resource "aws_iam_policy" "forge_ro" {
  name = "namiview-forge-ro"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Read"
        Effect = "Allow"
        Action = [
          "s3:ListBucket", "s3:GetObject", "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads", "s3:ListMultipartUploadParts",
        ]
        Resource = [
          "arn:aws:s3:::namiview-ml", "arn:aws:s3:::namiview-ml/*",
          "arn:aws:s3:::namiview-prod-bucket", "arn:aws:s3:::namiview-prod-bucket/*",
          "arn:aws:s3:::namiview-dev-bucket", "arn:aws:s3:::namiview-dev-bucket/*",
          "arn:aws:s3:::namiview-loki-logs", "arn:aws:s3:::namiview-loki-logs/*",
        ]
      },
      {
        Sid      = "Ec2Read"
        Effect   = "Allow"
        Action   = ["ec2:Describe*", "ec2:GetConsoleOutput"]
        Resource = "*"
      },
      {
        Sid      = "SqsRead"
        Effect   = "Allow"
        Action   = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ListQueues", "sqs:ListQueueTags", "sqs:ListDeadLetterSourceQueues"]
        Resource = "*"
      },
      {
        Sid      = "EcrRead"
        Effect   = "Allow"
        Action   = ["ecr:Describe*", "ecr:List*", "ecr:GetLifecyclePolicy", "ecr:GetRepositoryPolicy"]
        Resource = "*"
      },
      {
        Sid      = "Observability"
        Effect   = "Allow"
        Action   = ["cloudwatch:Get*", "cloudwatch:List*", "cloudwatch:Describe*", "logs:Get*", "logs:Describe*", "logs:FilterLogEvents"]
        Resource = "*"
      },
      {
        Sid      = "Quotas"
        Effect   = "Allow"
        Action   = ["servicequotas:Get*", "servicequotas:List*"]
        Resource = "*"
      },
      {
        Sid      = "Sts"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "forge_ro" {
  user       = aws_iam_user.forge_ro.name
  policy_arn = aws_iam_policy.forge_ro.arn
}

output "forge_ro_access_key_id" {
  value = aws_iam_access_key.forge_ro.id
}

output "forge_ro_secret_access_key" {
  value     = aws_iam_access_key.forge_ro.secret
  sensitive = true
}
