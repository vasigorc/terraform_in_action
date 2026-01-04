output "website_url" {
  description = "URL for the Ballroom web application"
  value       = aws_apigatewayv2_api.ballroom.api_endpoint
}

output "api_endpoint" {
  description = "Base URL for API endpoints"
  value       = "${aws_apigatewayv2_api.ballroom.api_endpoint}/api"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.tweets.name
  description = "DynamoDB table for tweets"
}

output "test_commands" {
  description = "Commands to test the deployed application"
  value       = <<-EOT
      # Visit the website:
      ${aws_apigatewayv2_api.ballroom.api_endpoint}

      # Test API - list tweets:
      curl ${aws_apigatewayv2_api.ballroom.api_endpoint}/api/tweet

      # Test API - create tweet:
      curl -X POST ${aws_apigatewayv2_api.ballroom.api_endpoint}/api/tweet \
        -H "Content-Type: application/json" \
        -d '{"name":"yourname","message":"Hello from AWS Lambda!"}'
   EOT
}
