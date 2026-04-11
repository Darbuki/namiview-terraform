variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "argocd_target_revision" {
  description = "Git branch/tag for ArgoCD to track"
  type        = string
  default     = "main"
}
