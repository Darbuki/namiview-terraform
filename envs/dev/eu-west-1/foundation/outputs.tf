output "s3_bucket_arn" {
  description = "ARN of the dev S3 bucket."
  value       = aws_s3_bucket.namiview-dev-bucket.arn
}

output "s3_bucket_name" {
  description = "Name of the dev S3 bucket."
  value       = aws_s3_bucket.namiview-dev-bucket.bucket
}

output "sqs_jobs_arn" {
  description = "ARN of the dev jobs SQS queue."
  value       = aws_sqs_queue.jobs.arn
}
