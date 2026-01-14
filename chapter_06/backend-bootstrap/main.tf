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

module "s3_backend" {
  source = "../modules/s3-backend"

  namespace           = "tfstate"
  force_destroy_state = true
}
