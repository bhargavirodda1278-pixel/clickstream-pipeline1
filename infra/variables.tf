variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "clickstream-pipeline"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "glue_job_timeout" {
  description = "Glue job timeout in minutes"
  type        = number
  default     = 60
}

variable "glue_job_max_retries" {
  description = "Maximum retries for Glue job"
  type        = number
  default     = 1
}

variable "glue_worker_type" {
  description = "Glue worker type (Standard, G.1X, G.2X)"
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Number of Glue workers"
  type        = number
  default     = 2
}

variable "crawler_schedule" {
  description = "Cron expression for Glue crawler schedule"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
}

variable "firehose_buffer_size" {
  description = "Firehose buffer size in MB"
  type        = number
  default     = 5
}

variable "firehose_buffer_interval" {
  description = "Firehose buffer interval in seconds"
  type        = number
  default     = 300
}

variable "s3_lifecycle_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

