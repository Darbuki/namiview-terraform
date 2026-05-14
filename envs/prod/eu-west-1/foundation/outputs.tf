output "anthropic_api_key_secret_arn" {
  description = "ARN of the Anthropic API key secret. Consumed by the workload layer (by name pattern, not remote state) and by ExternalSecrets in-cluster."
  value       = aws_secretsmanager_secret.anthropic_api_key.arn
}

output "triage_agent_github_pat_secret_arn" {
  description = "ARN of the triage agent's GitHub PAT secret. Consumed by ExternalSecrets in-cluster."
  value       = aws_secretsmanager_secret.triage_agent_github_pat.arn
}

output "anthropic_api_key_secret_name" {
  description = "Name of the Anthropic API key secret — stable reference for ExternalSecret manifests."
  value       = aws_secretsmanager_secret.anthropic_api_key.name
}

output "triage_agent_github_pat_secret_name" {
  description = "Name of the triage agent's GitHub PAT secret — stable reference for ExternalSecret manifests."
  value       = aws_secretsmanager_secret.triage_agent_github_pat.name
}

output "tailscale_operator_oauth_secret_arn" {
  description = "ARN of the Tailscale operator OAuth client secret. Consumed by ExternalSecrets in-cluster (looked up by name pattern, not remote_state)."
  value       = aws_secretsmanager_secret.tailscale_operator_oauth.arn
}

output "tailscale_operator_oauth_secret_name" {
  description = "Name of the Tailscale operator OAuth client secret."
  value       = aws_secretsmanager_secret.tailscale_operator_oauth.name
}

output "s3_bucket_prod_arn" {
  description = "ARN of the prod S3 bucket."
  value       = aws_s3_bucket.namiview-prod-bucket.arn
}

output "sqs_jobs_arn" {
  description = "ARN of the prod jobs SQS queue."
  value       = aws_sqs_queue.jobs.arn
}

output "homelab_prod_credentials_secret_name" {
  description = "Secrets Manager name holding the homelab prod IAM access key. Retrieve with: aws secretsmanager get-secret-value --secret-id <name>"
  value       = aws_secretsmanager_secret.homelab_prod_credentials.name
}

output "homelab_prod_credentials_secret_arn" {
  description = "ARN of the homelab prod credentials secret."
  value       = aws_secretsmanager_secret.homelab_prod_credentials.arn
}

output "ecr_repository_urls" {
  description = "Map of ECR repository name → URL. Consumed by CI workflows and Helm values."
  value = merge(
    { for k, v in aws_ecr_repository.app : k => v.repository_url },
    { for k, v in aws_ecr_repository.mutable : k => v.repository_url }
  )
}
