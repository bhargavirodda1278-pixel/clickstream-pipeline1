# Athena Workgroup
resource "aws_athena_workgroup" "clickstream" {
  name        = "${var.project_name}-workgroup"
  description = "Workgroup for clickstream analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }

  tags = local.common_tags
}

# Athena Named Query - Event Type Distribution
resource "aws_athena_named_query" "event_distribution" {
  name        = "Event Type Distribution"
  description = "Count events by type"
  database    = aws_glue_catalog_database.clickstream.name
  workgroup   = aws_athena_workgroup.clickstream.name

  query = <<-SQL
    SELECT 
      event_type,
      COUNT(*) as event_count,
      COUNT(DISTINCT user_id) as unique_users
    FROM transformed
    WHERE year = CAST(year(current_date) AS VARCHAR)
      AND month = LPAD(CAST(month(current_date) AS VARCHAR), 2, '0')
      AND day = LPAD(CAST(day(current_date) AS VARCHAR), 2, '0')
    GROUP BY event_type
    ORDER BY event_count DESC;
  SQL
}

# Athena Named Query - Daily Active Users
resource "aws_athena_named_query" "daily_active_users" {
  name        = "Daily Active Users"
  description = "Count unique users per day"
  database    = aws_glue_catalog_database.clickstream.name
  workgroup   = aws_athena_workgroup.clickstream.name

  query = <<-SQL
    SELECT 
      year,
      month,
      day,
      COUNT(DISTINCT user_id) as daily_active_users,
      COUNT(*) as total_events,
      ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT user_id), 2) as avg_events_per_user
    FROM transformed
    GROUP BY year, month, day
    ORDER BY year DESC, month DESC, day DESC
    LIMIT 30;
  SQL
}

# Athena Named Query - Product Performance
resource "aws_athena_named_query" "product_performance" {
  name        = "Product Performance"
  description = "Analyze product views and purchases"
  database    = aws_glue_catalog_database.clickstream.name
  workgroup   = aws_athena_workgroup.clickstream.name

  query = <<-SQL
    SELECT 
      product_id,
      SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END) as views,
      SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
      ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END), 0), 
        2
      ) as conversion_rate
    FROM transformed
    WHERE product_id IS NOT NULL
    GROUP BY product_id
    HAVING views > 10
    ORDER BY purchases DESC
    LIMIT 20;
  SQL
}

