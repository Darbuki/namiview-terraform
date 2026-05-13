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

output "homelab_dev_access_key_id" {
  description = "Access key ID for the homelab dev IAM user — bootstrap into k8s secret aws-credentials in namiview-dev namespace."
  value       = aws_iam_access_key.homelab_dev.id
  sensitive   = true
}

output "homelab_dev_secret_access_key" {
  description = "Secret access key for the homelab dev IAM user."
  value       = aws_iam_access_key.homelab_dev.secret
  sensitive   = true
}
