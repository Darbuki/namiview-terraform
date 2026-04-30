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

variable "argocd_dev_target_revision" {
  description = "Git branch/tag for the dev apps-root to track. Set to a feature branch while iterating, flip back to main once dev workload changes are merged."
  type        = string
  default     = "main"
}
