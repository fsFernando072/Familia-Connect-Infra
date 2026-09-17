output "bucket_ids" {
  value = { for k, v in awscc_s3_bucket.this : k => v.id }
}

output "bucket_arns" {
  value = { for k, v in awscc_s3_bucket.this : k => v.arn }
}
