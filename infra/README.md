# Infrastructure as Code (Terraform)

This directory contains Terraform configurations for the serverless clickstream pipeline.

## Resources Provisioned

- **S3 Buckets** (`s3.tf`): Raw data, transformed data, Glue scripts, Athena results, errors
- **Kinesis Firehose** (`kinesis.tf`): Ingestion stream with date partitioning
- **AWS Glue** (`glue.tf`): Database, ETL job, and crawler
- **Amazon Athena** (`athena.tf`): Workgroup and named queries
- **IAM Roles** (`iam.tf`): Service roles and policies
- **Configuration** (`main.tf`, `variables.tf`, `outputs.tf`): Main setup and variables

## How to Run

### Prerequisites
- AWS CLI configured with credentials
- Terraform >= 1.0 installed

### Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy resources
terraform apply

# Save outputs for later use
terraform output -json > ../terraform-outputs.json
```

### Verify Deployment

```bash
# Check created resources
terraform show

# View specific outputs
terraform output raw_bucket_name
terraform output glue_job_name
```

### Update Infrastructure

```bash
# Modify variables in variables.tf or pass via command line
terraform plan -var="project_name=my-custom-name"
terraform apply -var="project_name=my-custom-name"
```

### Destroy Resources

```bash
# IMPORTANT: Empty S3 buckets first
terraform output -json | jq -r '.[] | select(.value | strings) | .value' | while read bucket; do
  aws s3 rm "s3://${bucket}" --recursive
done

# Destroy all resources
terraform destroy
```

## File Descriptions

- `main.tf` - Provider configuration and common resources
- `variables.tf` - Input variables with defaults
- `outputs.tf` - Output values (bucket names, ARNs, etc.)
- `s3.tf` - S3 bucket configurations with lifecycle policies
- `kinesis.tf` - Kinesis Firehose delivery stream with date partitioning
- `glue.tf` - Glue database, job, and crawler configurations
- `athena.tf` - Athena workgroup and named queries
- `iam.tf` - IAM roles and policies for all services

## Configuration Variables

Key variables in `variables.tf`:

```hcl
aws_region              = "us-east-1"        # AWS region
project_name            = "clickstream-pipeline"
environment             = "dev"
glue_worker_type        = "G.1X"             # Glue worker type
glue_number_of_workers  = 2                  # Number of Glue workers
crawler_schedule        = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
```

## Outputs

After deployment, the following outputs are available:

- `raw_bucket_name` - S3 bucket for raw JSON data
- `transformed_bucket_name` - S3 bucket for Parquet data
- `firehose_stream_name` - Kinesis Firehose stream name
- `glue_job_name` - Glue transformation job name
- `glue_crawler_name` - Glue crawler name
- `athena_workgroup_name` - Athena workgroup name

## Notes

- S3 bucket names are globally unique - a random suffix is added
- Glue job script is automatically uploaded from `../glue/clickstream_transform.py`
- Default lifecycle policies archive raw data to Glacier after 90 days
- Athena results are automatically deleted after 30 days

