output "dev_bucket_name" {
  value = aws_s3_bucket.namiview-dev-bucket.bucket
}

output "dev_bucket_arn" {
  value = aws_s3_bucket.namiview-dev-bucket.arn
}
