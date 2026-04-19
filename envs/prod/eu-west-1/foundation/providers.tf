terraform {
  required_version = ">= 1.14.0"

  # Separate state key from the flat (workload) layer so this layer
  # survives EKS teardowns. Do NOT change this key.
  backend "s3" {
    bucket       = "namiview-terraform-state"
    key          = "prod/eu-west-1/foundation/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  # Foundation layer is AWS-only: no cluster exists during early bootstrap,
  # so we deliberately omit the kubernetes/helm providers here.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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
      Layer       = "foundation"
    }
  }
}
