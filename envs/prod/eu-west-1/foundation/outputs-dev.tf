output "anthropic_api_key_dev_secret_arn" {
  value = aws_secretsmanager_secret.anthropic_api_key_dev.arn
}

output "anthropic_api_key_dev_secret_name" {
  value = aws_secretsmanager_secret.anthropic_api_key_dev.name
}

output "triage_agent_github_pat_dev_secret_arn" {
  value = aws_secretsmanager_secret.triage_agent_github_pat_dev.arn
}

output "triage_agent_github_pat_dev_secret_name" {
  value = aws_secretsmanager_secret.triage_agent_github_pat_dev.name
}

output "tailscale_operator_oauth_dev_secret_arn" {
  value = aws_secretsmanager_secret.tailscale_operator_oauth_dev.arn
}

output "tailscale_operator_oauth_dev_secret_name" {
  value = aws_secretsmanager_secret.tailscale_operator_oauth_dev.name
}

output "dev_bucket_name" {
  value = aws_s3_bucket.namiview-dev-bucket.bucket
}

output "dev_bucket_arn" {
  value = aws_s3_bucket.namiview-dev-bucket.arn
}
