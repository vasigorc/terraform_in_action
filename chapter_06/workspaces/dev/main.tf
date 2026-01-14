terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Simple S3 bucket as example for dev infrastructure
resource "aws_s3_bucket" "dev_bucket" {
  bucket_prefix = "dev-example-"
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

