variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used as the prefix for Secrets Manager names so the workload layer's ESO IAM policy can reference them by ARN pattern."
  type        = string
}

variable "cost_alert_emails" {
  description = "Email addresses that receive AWS cost-guardrail alerts (S3 budget thresholds)."
  type        = list(string)
  default     = ["darl293@gmail.com"]
}
