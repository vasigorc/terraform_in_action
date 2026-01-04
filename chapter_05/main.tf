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

  lambda_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
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

#=========================================
# IAM (Lambda Execution Roles & Policies)
# ========================================
resource "aws_iam_role" "lambda_api_role" {
  name = "${local.namespace}-lambda-api-role"

  # Trust policy: allows Lambda service to assume this role
  assume_role_policy = local.lambda_assume_role_policy

  tags = local.common_tags
}

# Attach AWS managed policy for CW Logs (basic Lambda execution)
resource "aws_iam_role_policy_attachment" "lambda_api_logs" {
  role       = aws_iam_role.lambda_api_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom inline policy for DynamoDB access (for API function)
resource "aws_iam_role_policy" "lambda_api_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda_api_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = aws_dynamodb_table.tweets.arn
      }
    ]
  })
}

resource "aws_iam_role" "lambda_web_role" {
  name = "${local.namespace}-lambda-web-role"

  # Same Lambda trust policy as API role
  assume_role_policy = local.lambda_assume_role_policy

  tags = local.common_tags
}

# Web function only needs CW Logs
resource "aws_iam_role_policy_attachment" "lambda_web_logs" {
  role       = aws_iam_role.lambda_web_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#=================================================
# COMPUTE (Lambda Functions)
# ================================================
resource "aws_lambda_function" "api" {
  function_name = "${local.namespace}-api"
  role          = aws_iam_role.lambda_api_role.arn

  # code location on S3
  s3_bucket        = aws_s3_bucket.lambda_packages.id
  s3_key           = aws_s3_object.api_package.key
  source_code_hash = data.archive_file.api_function.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs20.x"
  timeout = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.tweets.name
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "web" {
  function_name = "${local.namespace}-web"
  role          = aws_iam_role.lambda_web_role.arn

  s3_bucket        = aws_s3_bucket.lambda_packages.id
  s3_key           = aws_s3_object.web_package.key
  source_code_hash = data.archive_file.web_function.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs20.x"
  timeout = 10

  tags = local.common_tags
}

#===========================================
# API GATEWAY (v2 HTTP API)
#===========================================
resource "aws_apigatewayv2_api" "ballroom" {
  name          = "${local.namespace}-api"
  protocol_type = "HTTP"

  # CORS for browser access
  cors_configuration {
    allow_origins  = ["*"]
    allow_methods  = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers  = ["*"]
    expose_headers = ["*"]
    max_age        = 3600
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "api" {
  api_id                 = aws_apigatewayv2_api.ballroom.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "web" {
  api_id                 = aws_apigatewayv2_api.ballroom.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.web.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Route: /api/{proxy} -> API Lambda (tweets CRUD)
resource "aws_apigatewayv2_route" "api" {
  api_id    = aws_apigatewayv2_api.ballroom.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

# Route: /{proxy+} -> Web Lambda (static files)
resource "aws_apigatewayv2_route" "web_root" {
  api_id    = aws_apigatewayv2_api.ballroom.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.web.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.ballroom.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gw_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ballroom.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_web" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ballroom.execution_arn}/*/*"
}
