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

output "homelab_dev_credentials_secret_name" {
  description = "Secrets Manager name holding the homelab dev IAM access key. Retrieve with: aws secretsmanager get-secret-value --secret-id <name>"
  value       = aws_secretsmanager_secret.homelab_dev_credentials.name
}

output "homelab_dev_credentials_secret_arn" {
  description = "ARN of the homelab dev credentials secret."
  value       = aws_secretsmanager_secret.homelab_dev_credentials.arn
}
