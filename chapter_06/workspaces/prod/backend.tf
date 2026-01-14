terraform {
  backend "s3" {
    bucket  = "tfstate-tg4dsqccl4c0ohyw-state-bucket"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    profile = "vasile_tf_admin"
  }
}
