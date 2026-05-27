resource "aws_s3_bucket" "namiview-prod-bucket" {
  bucket = "namiview-prod-bucket"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "namiview_prod" {
  bucket = aws_s3_bucket.namiview-prod-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "namiview_prod" {
  bucket = aws_s3_bucket.namiview-prod-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "namiview_prod" {
  bucket = aws_s3_bucket.namiview-prod-bucket.id

  rule {
    id     = "expire-pending"
    status = "Enabled"
    filter { prefix = "pending/" }
    expiration { days = 1 }
  }
}
