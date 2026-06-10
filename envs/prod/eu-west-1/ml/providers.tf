terraform {
  required_version = ">= 1.14.0"

  # Separate state from foundation: this whole layer is disposable —
  # `terraform destroy` here must never threaten the namiview-ml bucket
  # (which lives in foundation) or anything serving traffic.
  backend "s3" {
    bucket       = "namiview-terraform-state"
    key          = "prod/eu-west-1/ml/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "namiview"
      Environment = "prod"
      ManagedBy   = "terraform"
      Layer       = "ml"
    }
  }
}
