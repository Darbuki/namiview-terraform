resource "aws_secretsmanager_secret" "anthropic_api_key_dev" {
  name        = "namiview-dev/anthropic-api-key"
  description = "Dev counterpart of namiview-prod/anthropic-api-key."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "triage_agent_github_pat_dev" {
  name        = "namiview-dev/triage-agent-github-pat"
  description = "Dev counterpart of namiview-prod/triage-agent-github-pat."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "tailscale_operator_oauth_dev" {
  name        = "namiview-dev/tailscale-operator-oauth"
  description = "Dev counterpart of namiview-prod/tailscale-operator-oauth."

  lifecycle {
    prevent_destroy = true
  }
}
