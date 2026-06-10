data "aws_iam_policy_document" "ml_train_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ml_train" {
  name               = "namiview-ml-train"
  assume_role_policy = data.aws_iam_policy_document.ml_train_trust.json
}

# The instance can touch exactly one bucket and nothing else.
resource "aws_iam_role_policy" "ml_train_s3" {
  name = "ml-bucket-rw"
  role = aws_iam_role.ml_train.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Bucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::${var.ml_bucket}"
      },
      {
        Sid    = "Objects"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts",
        ]
        Resource = "arn:aws:s3:::${var.ml_bucket}/*"
      }
    ]
  })
}

# Session Manager shell access for debugging — no SSH keys, no inbound ports.
resource "aws_iam_role_policy_attachment" "ml_train_ssm" {
  role       = aws_iam_role.ml_train.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ml_train" {
  name = "namiview-ml-train"
  role = aws_iam_role.ml_train.name
}
