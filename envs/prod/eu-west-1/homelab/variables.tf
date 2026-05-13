variable "region" {
  description = "AWS region (used for SM/ECR ARNs referenced by in-cluster ESO)."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the homelab k3s cluster."
  type        = string
  default     = "~/.kube/config"
}
