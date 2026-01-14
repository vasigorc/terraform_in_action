output "bucket_name" {
  value       = aws_s3_bucket.s3_bucket.id
  description = "S3 bucket name for state storage"
}

output "bucket_arn" {
  value       = aws_s3_bucket.s3_bucket.arn
  description = "S3 bucket ARN"
}

output "region" {
  value       = data.aws_region.current.name
  description = "AWS region"
}
