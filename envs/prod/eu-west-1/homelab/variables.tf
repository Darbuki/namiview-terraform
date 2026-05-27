variable "region" {
  description = "AWS region (used for SM/ECR ARNs referenced by in-cluster ESO)."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the homelab k3s cluster."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "kubeconfig context name to use — pins the provider to the homelab cluster regardless of the user's current-context."
  type        = string
  default     = "homelab"
}

variable "argocd_target_revision" {
  description = "Git ref ArgoCD tracks for the prod apps-homelab root Application."
  type        = string
  default     = "main"
}

variable "argocd_dev_target_revision" {
  description = "Git ref ArgoCD tracks for the dev apps-homelab-dev root Application."
  type        = string
  default     = "main"
}

variable "argocd_infrastructure_target_revision" {
  description = "Git ref ArgoCD tracks for the infrastructure-homelab root Application."
  type        = string
  default     = "main"
}
