variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
variable "s3_bucket_name" {
  description = "Name of the S3 bucket to store CSV files"
  type        = string
  default     = "csv-to-athena-sql-data-lake"
}
variable "athena_database_name" {
  description = "Name of the Athena database"
  type        = string
  default     = "csv_database"
}
variable "project_name" {
  description = "Name of the project for tagging resources"
  type        = string
  default     = "CSV to Athena SQL"
}
