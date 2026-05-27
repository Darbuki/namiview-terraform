terraform {
  required_version = ">= 1.14.0"

  # Cluster-coupled bootstrap layer. Durable AWS resources (IAM users,
  # buckets, queues, secrets, ECR) live in the foundation layers.
  backend "s3" {
    bucket       = "namiview-terraform-state"
    key          = "prod/eu-west-1/homelab/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "namiview"
      Environment = "prod"
      ManagedBy   = "terraform"
      Layer       = "homelab"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}
