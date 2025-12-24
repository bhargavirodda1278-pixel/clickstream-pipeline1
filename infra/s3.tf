# S3 Bucket for Raw Clickstream Data
resource "aws_s3_bucket" "raw_data" {
  bucket = "${var.project_name}-raw-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name = "Raw Clickstream Data"
  })
}

resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = var.s3_lifecycle_days
      storage_class = "GLACIER"
    }
  }
}

# S3 Bucket for Transformed Data (Parquet)
resource "aws_s3_bucket" "transformed_data" {
  bucket = "${var.project_name}-transformed-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name = "Transformed Clickstream Data"
  })
}

resource "aws_s3_bucket_versioning" "transformed_data" {
  bucket = aws_s3_bucket.transformed_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for Glue Scripts
resource "aws_s3_bucket" "glue_scripts" {
  bucket = "${var.project_name}-glue-scripts-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name = "Glue ETL Scripts"
  })
}

# Upload Glue transformation script
resource "aws_s3_object" "glue_transform_script" {
  bucket = aws_s3_bucket.glue_scripts.id
  key    = "scripts/clickstream_transform.py"
  source = "${path.module}/../glue/clickstream_transform.py"
  etag   = filemd5("${path.module}/../glue/clickstream_transform.py")

  tags = local.common_tags
}

# S3 Bucket for Athena Query Results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-athena-results-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name = "Athena Query Results"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "delete-old-results"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# S3 Bucket for Errors
resource "aws_s3_bucket" "errors" {
  bucket = "${var.project_name}-errors-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name = "Pipeline Errors"
  })
}

# Block public access for all buckets
resource "aws_s3_bucket_public_access_block" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "transformed_data" {
  bucket = aws_s3_bucket.transformed_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "errors" {
  bucket = aws_s3_bucket.errors.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

