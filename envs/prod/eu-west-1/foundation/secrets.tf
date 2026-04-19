########################################################################
# Foundation-layer secrets
#
# These are the "persistent" secrets that must survive an EKS teardown.
# Values are populated by hand in the AWS Console after first apply and
# must NOT be destroyed when the workload/EKS state is torn down — hence
# `prevent_destroy = true` on every resource.
#
# Naming convention: "${cluster_name}/<purpose>". The workload layer's
# ESO IAM policy grants access via ARN name pattern
# (".../secret:${cluster_name}/<purpose>-*") so this layer's state is
# not coupled to the workload layer.
########################################################################

resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name        = "${var.cluster_name}/anthropic-api-key"
  description = "Anthropic API key for the incident-triage agent (Claude Haiku). Populated by hand."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "triage_agent_github_pat" {
  name        = "${var.cluster_name}/triage-agent-github-pat"
  description = "GitHub PAT used by the triage agent to open issues/PRs. Fine-grained, scoped to the namiview repo. Populated by hand."

  lifecycle {
    prevent_destroy = true
  }
}
