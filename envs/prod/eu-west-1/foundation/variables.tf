variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used as the prefix for Secrets Manager names so the workload layer's ESO IAM policy can reference them by ARN pattern."
  type        = string
}
