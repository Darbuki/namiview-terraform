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
