# ML experiment storage (issue namiview#230) — datasets, packed training code,
# and checkpoints for the Nami v2 model. Lives in foundation because the data
# must survive teardown of the ephemeral training rig (envs/.../ml layer).
# Single bucket for the experiment, no dev mirror: accepted exception to
# dev-mirrors-prod (nothing serves traffic from here).
resource "aws_s3_bucket" "ml" {
  bucket = "namiview-ml"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "ml" {
  bucket = aws_s3_bucket.ml.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml" {
  bucket = aws_s3_bucket.ml.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Versioning makes deletes/overwrites recoverable. Matters because the forge
# launch grant (iam-forge-launch.tf) lets the agent run a box carrying the
# ml-train role, which holds s3:DeleteObject on this bucket — without versioning,
# an accidental or hostile wipe of the datasets/code/checkpoints is unrecoverable.
# Also covers plain operator error. Old versions are reaped after 30d (below).
resource "aws_s3_bucket_versioning" "ml" {
  bucket = aws_s3_bucket.ml.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ml" {
  bucket = aws_s3_bucket.ml.id

  # Spot interruptions leave half-uploaded checkpoints behind; reap them.
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Bound the cost of versioning: keep a 30-day recovery window, then purge
  # superseded/deleted versions.
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
