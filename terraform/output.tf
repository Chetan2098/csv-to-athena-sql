output "s3_bucket_name" {
  description = "Name of the S3 bucket created for data lake"
  value       = aws_s3_bucket.data_lake.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket created for data lake"
  value       = aws_s3_bucket.data_lake.arn
}

output "glue_role_arn" {
  description = "ARN of the IAM role created for Glue"
  value       = aws_iam_role.glue_role.arn
}

output "glue_role_name" {
  description = "Name of the IAM role created for Glue"
  value       = aws_iam_role.glue_role.name
}

output "glue_job_name" {
  description = "Name of the Glue job"
  value       = aws_glue_job.csv_to_curated_job.name
}

output "glue_database_name" {
  description = "Name of the Glue Catalog database"
  value       = aws_glue_catalog_database.data_catalog_db.name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.csv_workgroup.name
}

output "athena_database_name" {
  description = "Name of the Athena database"
  value       = aws_athena_database.csv_database.name
}

output "athena_results_location" {
  description = "S3 location for Athena query results"
  value       = "s3://${aws_s3_bucket.data_lake.bucket}/athena-results/"
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
