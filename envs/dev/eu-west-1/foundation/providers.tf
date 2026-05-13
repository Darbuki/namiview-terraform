terraform {
  required_version = ">= 1.14.0"

  backend "s3" {
    bucket       = "namiview-terraform-state"
    key          = "dev/eu-west-1/foundation/terraform.tfstate"
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

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "namiview"
      Environment = "dev"
      ManagedBy   = "terraform"
      Layer       = "foundation"
    }
  }
}
