resource "random_string" "rand" {
  length  = 24
  special = false
  upper   = false
}

locals {
  namespace = substr("${var.namespace}-${random_string.rand.result}", 0, 24)

  common_tags = {
    Project     = "terraform-in-action"
    Chapter     = "05"
    Application = "ballroom"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "lambda_packages" {
  bucket = "${local.namespace}-lambda_packages"
  tags   = local.common_tags
}

data "archive_file" "api_function" {
  type        = "zip"
  source_dir  = "${path.module}/functions/api"
  output_path = "${path.module}/dist/api.zip"
}

resource "aws_s3_object" "api_package" {
  bucket = aws_s3_bucket.lambda_packages.id
  key    = "api.zip"
  source = data.archive_file.api_function.output_path
  etag   = filemd5(data.archive_file.api_function.output_path)
}

data "archive_file" "web_function" {
  type        = "zip"
  source_dir  = "${path.module}/functions/web"
  output_path = "${path.module}/dist/web.zip"
}

resource "aws_s3_object" "web_package" {
  bucket = aws_s3_bucket.lambda_packages.id
  key    = "web.zip"
  source = data.archive_file.web_function.output_path
  etag   = filemd5(data.archive_file.web_function.output_path)
}

resource "aws_dynamodb_table" "tweets" {
  name         = "${local.namespace}-tweets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "name"
  range_key    = "uuid"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "uuid"
    type = "S"
  }

  tags = local.common_tags
}
