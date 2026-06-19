# Launch grant for the forge box (the read-only namiview-forge-ro user), so the
# agent can run Nami v2 training itself: upload code, launch ONE g4dn spot rig
# from the namiview-ml-train template, and kill a diverged run. This is a
# DELIBERATE, NARROW write-capability bolt-on to an otherwise read-only identity
# — kept in its OWN policy so the read-only baseline (iam-forge-ro.tf) stays
# honest and this launch power is independently revocable (just detach/remove
# this file). Scoping (verified against an adversarial review):
#   - region-locked to eu-west-1 on every EC2 statement
#   - instance type HARD-capped to g4dn.xlarge via an explicit Deny (an Allow
#     condition alone is bypassable — Deny is the only thing IAM can't union away)
#   - iam:PassRole locked to the single namiview-ml-train role AND to ec2 only
#   - CreateTags allowed only at launch (ec2:CreateAction=RunInstances)
#   - terminate limited to instances tagged Name=namiview-ml-train
#   - S3 write limited to the code/ upload path (read already in forge_ro)
locals {
  forge_launch_acct = data.aws_caller_identity.current.account_id
  ml_train_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/namiview-ml-train"
}

resource "aws_iam_policy" "forge_launch" {
  name = "namiview-forge-launch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "S3UploadCode"
        Effect    = "Allow"
        Action    = ["s3:PutObject", "s3:CreateMultipartUpload", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
        Resource  = "arn:aws:s3:::namiview-ml/code/*"
        Condition = { Bool = { "aws:SecureTransport" = "true" } }
      },
      {
        # RunInstances is authorized against EVERY resource it creates/consumes —
        # omit one ARN and the whole call is denied. spot-instances-request is
        # required because the template launches one-time SPOT.
        Sid    = "RunInstances"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = [
          "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:instance/*",
          "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:volume/*",
          "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:network-interface/*",
          "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:spot-instances-request/*",
          "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:subnet/*",
          "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:security-group/*",
          "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:launch-template/*",
          "arn:aws:ec2:${var.region}::image/*",
          "arn:aws:ec2:${var.region}::snapshot/*",
        ]
        Condition = { StringEquals = { "aws:RequestedRegion" = var.region } }
      },
      {
        # The real instance-type cap. A leaked key can otherwise launch a
        # p4d.24xlarge (~$32/h) — an Allow-only condition is bypassable, so DENY
        # anything that isn't the g4dn.xlarge the template uses.
        Sid       = "DenyNonTrainingInstanceType"
        Effect    = "Deny"
        Action    = "ec2:RunInstances"
        Resource  = "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:instance/*"
        Condition = { StringNotEquals = { "ec2:InstanceType" = "g4dn.xlarge" } }
      },
      {
        # The template tags only the instance (Name/Project/Layer). CreateAction
        # gate => this can ONLY tag at launch, never relabel existing resources.
        Sid      = "TagOnLaunch"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:instance/*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
            "ec2:CreateAction"    = "RunInstances"
          }
        }
      },
      {
        # Passing the instance profile requires PassRole on the ROLE. PassedToService
        # = ec2 prevents a leaked key from attaching this S3-writing role anywhere else.
        Sid       = "PassMlTrainRole"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = local.ml_train_role_arn
        Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } }
      },
      {
        # Kill a diverged run before the 8h watchdog. Tag-scoped: can ONLY touch
        # the training rig (Name=namiview-ml-train, set at launch above), nothing
        # else in the account. Remove this statement for a launch-only grant.
        Sid      = "TerminateTrainingRig"
        Effect   = "Allow"
        Action   = "ec2:TerminateInstances"
        Resource = "arn:aws:ec2:${var.region}:${local.forge_launch_acct}:instance/*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"  = var.region
            "ec2:ResourceTag/Name" = "namiview-ml-train"
          }
        }
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "forge_launch" {
  user       = aws_iam_user.forge_ro.name
  policy_arn = aws_iam_policy.forge_launch.arn
}
