output "raw_bucket_name" {
  description = "Name of the raw data S3 bucket"
  value       = aws_s3_bucket.raw_data.id
}

output "transformed_bucket_name" {
  description = "Name of the transformed data S3 bucket"
  value       = aws_s3_bucket.transformed_data.id
}

output "scripts_bucket_name" {
  description = "Name of the Glue scripts S3 bucket"
  value       = aws_s3_bucket.glue_scripts.id
}

output "athena_results_bucket_name" {
  description = "Name of the Athena results S3 bucket"
  value       = aws_s3_bucket.athena_results.id
}

output "errors_bucket_name" {
  description = "Name of the errors S3 bucket"
  value       = aws_s3_bucket.errors.id
}

output "firehose_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.clickstream.name
}

output "firehose_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.clickstream.arn
}

output "glue_database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.clickstream.name
}

output "glue_job_name" {
  description = "Name of the Glue transformation job"
  value       = aws_glue_job.transform_clickstream.name
}

output "glue_crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.clickstream_crawler.name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.clickstream.name
}

output "glue_job_role_arn" {
  description = "ARN of the Glue job IAM role"
  value       = aws_iam_role.glue_job_role.arn
}

output "firehose_role_arn" {
  description = "ARN of the Firehose IAM role"
  value       = aws_iam_role.firehose_role.arn
}

