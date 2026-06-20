# Loki chunk/index storage. Lives in foundation so it survives EKS teardown
# during the homelab migration — the homelab Loki install reads/writes here.
resource "aws_s3_bucket" "loki" {
  bucket = "namiview-loki-logs"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket = aws_s3_bucket.loki.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "expire-loki-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = 2
    }

    # Loki flushes chunks as multipart uploads; an aborted/failed flush can
    # leave orphaned MPU parts that are billed as storage indefinitely and
    # are NOT removed by the object `expiration` rule above. Clean them up.
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
