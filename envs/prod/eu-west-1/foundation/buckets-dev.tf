resource "aws_s3_bucket" "namiview-dev-bucket" {
  bucket = "namiview-dev-bucket"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "namiview_dev" {
  bucket = aws_s3_bucket.namiview-dev-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "namiview_dev" {
  bucket = aws_s3_bucket.namiview-dev-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
