# Glue Catalog Database
resource "aws_glue_catalog_database" "clickstream" {
  name        = "clickstream_db"
  description = "Database for clickstream analytics"

  tags = local.common_tags
}

# Glue Job for ETL Transformation
resource "aws_glue_job" "transform_clickstream" {
  name     = "${var.project_name}-transform-job"
  role_arn = aws_iam_role.glue_job_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_scripts.id}/${aws_s3_object.glue_transform_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.glue_scripts.id}/spark-logs/"
    "--TempDir"                          = "s3://${aws_s3_bucket.glue_scripts.id}/temp/"
    "--SOURCE_BUCKET"                    = aws_s3_bucket.raw_data.id
    "--TARGET_BUCKET"                    = aws_s3_bucket.transformed_data.id
    "--DATABASE_NAME"                    = aws_glue_catalog_database.clickstream.name
  }

  # Resource allocation
  glue_version      = "4.0"
  worker_type       = var.glue_worker_type
  number_of_workers = var.glue_number_of_workers
  timeout           = var.glue_job_timeout
  max_retries       = var.glue_job_max_retries

  tags = local.common_tags

  depends_on = [
    aws_s3_object.glue_transform_script
  ]
}

# Glue Crawler
resource "aws_glue_crawler" "clickstream_crawler" {
  name          = "${var.project_name}-crawler"
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.clickstream.name

  s3_target {
    path = "s3://${aws_s3_bucket.transformed_data.id}/transformed/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  # Schedule (optional - comment out for manual runs)
  schedule = var.crawler_schedule

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = local.common_tags
}

# CloudWatch Log Group for Glue Jobs
resource "aws_cloudwatch_log_group" "glue_jobs" {
  name              = "/aws-glue/jobs/output"
  retention_in_days = 7

  tags = local.common_tags
}

# CloudWatch Log Group for Glue Crawlers
resource "aws_cloudwatch_log_group" "glue_crawlers" {
  name              = "/aws-glue/crawlers"
  retention_in_days = 7

  tags = local.common_tags
}

