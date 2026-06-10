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
}
