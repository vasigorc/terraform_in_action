output "bucket_name" {
  value       = module.s3_backend.bucket_name
  description = "S3 bucket name for state storage"
}

output "region" {
  value       = module.s3_backend.region
  description = "AWS region"
}
