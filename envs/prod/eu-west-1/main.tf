data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "namiview-prod-bucket" {
  bucket = "namiview-prod-bucket"
}