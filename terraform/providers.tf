# ============================================================================
# providers.tf — root module
# ============================================================================
# Personal learning sandbox. State is local on purpose (see README) — this is
# not how a fuller shared platform setup would normally work, but for a solo
# sandbox, local state is one less thing to break.
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No backend block -> local terraform.tfstate in this directory.
  # If you want to practice remote state later, add an S3 backend block here
  # and re-init with `terraform init -migrate-state`.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_prefix
      Purpose     = "learning"
      ManagedBy   = "terraform"
      Environment = var.environment
      Owner       = var.owner_tag
    }
  }
}
