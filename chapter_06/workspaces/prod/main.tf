terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Simple S3 bucket as example for prod infrastructure
resource "aws_s3_bucket" "prod_bucket" {
  bucket_prefix = "prod-example-"
  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

