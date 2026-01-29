terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Local variable for lowercase project name
locals {
  project_name_lower = replace(lower(var.project_name), "/[^a-z0-9-]/", "-")
}

#############################
# S3 DATA LAKE
#############################

resource "aws_s3_bucket" "data_lake" {
  bucket = var.s3_bucket_name

  tags = {
    Project = var.project_name
    Purpose = "Data Lake"
  }
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake_encryption" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "data_lake_pab" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create S3 directory structure using objects
resource "aws_s3_object" "raw_zone" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/"
}

resource "aws_s3_object" "curated_zone" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "curated/"
}

resource "aws_s3_object" "logs_zone" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "logs/"
}

resource "aws_s3_object" "scripts_zone" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/"
}

resource "aws_s3_object" "athena_results_zone" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "athena-results/"
}

#############################
# RAW DATA UPLOAD (Dynamic - All CSV files)
#############################

resource "aws_s3_object" "raw_data_files" {
  for_each = fileset("${path.module}/../local_s3/raw/orders/", "*.csv")

  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/orders/${each.value}"
  source = "${path.module}/../local_s3/raw/orders/${each.value}"
  etag   = filemd5("${path.module}/../local_s3/raw/orders/${each.value}")

  depends_on = [aws_s3_object.raw_zone]
}

#############################
# GLUE SCRIPT UPLOAD
#############################

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/csv_to_curated.py"
  source = "${path.module}/../glue/csv_to_curated.py"
  etag   = filemd5("${path.module}/../glue/csv_to_curated.py")

  depends_on = [aws_s3_object.scripts_zone]
}

#############################
# IAM ROLE FOR GLUE
#############################

resource "aws_iam_role" "glue_role" {
  name = "${local.project_name_lower}-glue-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

#############################
# IAM ROLE POLICY FOR GLUE
#############################

resource "aws_iam_policy" "glue_policy" {
  name        = "${local.project_name_lower}-glue-policy"
  description = "Policy for Glue jobs to access S3 and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataLakeAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws-glue/*"
      },
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_policy.arn
}

#############################
# GLUE DATA CATALOG
#############################

resource "aws_glue_catalog_database" "data_catalog_db" {
  name        = "${local.project_name_lower}db"
  description = "Glue Data Catalog database for CSV data platform project"

  catalog_id = data.aws_caller_identity.current.account_id
}

#############################
# GLUE JOB
#############################

resource "aws_glue_job" "csv_to_curated_job" {
  name         = "${var.project_name}-csv-to-curated"
  role_arn     = aws_iam_role.glue_role.arn
  glue_version = "4.0"

  command {
    name            = "pythonshell"
    script_location = "s3://${aws_s3_bucket.data_lake.bucket}/scripts/csv_to_curated.py"
    python_version  = "3.9"
  }

  default_arguments = {
    "--job-language"   = "python"
    "--raw_bucket"     = aws_s3_bucket.data_lake.bucket
    "--raw_prefix"     = "raw/orders/"
    "--curated_prefix" = "curated/orders/"
    "--TempDir"        = "s3://${aws_s3_bucket.data_lake.bucket}/temp/"
  }

  max_capacity = 1.0
  timeout      = 2880

  tags = {
    Project = var.project_name
  }

  depends_on = [aws_s3_object.glue_script]
}

#############################
# ATHENA WORKGROUP
#############################

resource "aws_athena_workgroup" "csv_workgroup" {
  name          = "${local.project_name_lower}-workgroup"
  force_destroy = false

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.bucket}/athena-results/"
    }

    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
  }

  tags = {
    Project = var.project_name
    Purpose = "Athena Workgroup for CSV to SQL"
  }

  depends_on = [aws_s3_object.athena_results_zone]
}

#############################
# ATHENA DATABASE
#############################

resource "aws_athena_database" "csv_database" {
  name   = var.athena_database_name
  bucket = aws_s3_bucket.data_lake.bucket

  properties = {
    classification = "parquet"
  }

  depends_on = [aws_athena_workgroup.csv_workgroup]
}

#############################
# DATA SOURCE
#############################

data "aws_caller_identity" "current" {}


