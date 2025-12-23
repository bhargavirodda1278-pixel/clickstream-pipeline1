# Setup Guide

Step-by-step instructions for deploying the clickstream pipeline.

## Prerequisites

```bash
# Verify prerequisites
aws --version        # AWS CLI 2.x
terraform --version  # Terraform >= 1.0
python3 --version    # Python 3.9+
jq --version         # jq 1.6+
```

Install missing tools (macOS):
```bash
brew install awscli
brew install hashicorp/tap/terraform
brew install jq
```

## AWS Configuration

```bash
# Configure credentials
aws configure

# Verify
aws sts get-caller-identity

# Set environment variables (optional)
export AWS_REGION="us-east-1"
export PROJECT_NAME="clickstream-pipeline"
```

**Required AWS permissions:**
- S3, Kinesis Firehose, Glue, Athena, IAM

## Infrastructure Deployment

```bash
cd infra
terraform init
terraform plan
terraform apply
terraform output -json > ../terraform-outputs.json
cd ..
```

**Resources created:**
- 5 S3 buckets
- 1 Kinesis Firehose stream
- 1 Glue database, job, crawler
- 1 Athena workgroup
- IAM roles and policies

Deployment time: ~2-3 minutes

## Testing the Pipeline

### 1. Upload Sample Data

```bash
RAW_BUCKET=$(cat terraform-outputs.json | jq -r '.raw_bucket_name.value')
YEAR=$(date -u +"%Y")
MONTH=$(date -u +"%m")
DAY=$(date -u +"%d")

aws s3 cp sample-data/sample_events.json \
  "s3://${RAW_BUCKET}/raw/year=${YEAR}/month=${MONTH}/day=${DAY}/sample_events.json"
```

### 2. Run Glue Job

```bash
aws glue start-job-run --job-name ${PROJECT_NAME}-transform-job

# Monitor status
aws glue get-job-runs --job-name ${PROJECT_NAME}-transform-job --max-results 1
```

Job states: `STARTING` → `RUNNING` → `SUCCEEDED`

### 3. Run Glue Crawler

```bash
aws glue start-crawler --name ${PROJECT_NAME}-crawler

# Check status
aws glue get-crawler --name ${PROJECT_NAME}-crawler --query 'Crawler.State'
```

### 4. Query with Athena

```bash
WORKGROUP=$(cat terraform-outputs.json | jq -r '.athena_workgroup_name.value')
RESULTS_BUCKET=$(cat terraform-outputs.json | jq -r '.athena_results_bucket_name.value')

aws athena start-query-execution \
  --query-string "SELECT event_type, COUNT(*) as count FROM transformed GROUP BY event_type;" \
  --query-execution-context "Database=clickstream_db" \
  --result-configuration "OutputLocation=s3://${RESULTS_BUCKET}/" \
  --work-group ${WORKGROUP}
```

## Monitoring

**View Glue job logs:**
```bash
aws logs tail /aws-glue/jobs/output --follow
```

**Check S3 data:**
```bash
aws s3 ls s3://${RAW_BUCKET}/raw/ --recursive
TRANSFORMED_BUCKET=$(cat terraform-outputs.json | jq -r '.transformed_bucket_name.value')
aws s3 ls s3://${TRANSFORMED_BUCKET}/transformed/ --recursive
```

## Cleanup

```bash
# Empty S3 buckets
for bucket in $(cat terraform-outputs.json | jq -r '.[] | select(.value | strings) | .value'); do
  aws s3 rm "s3://${bucket}" --recursive
done

# Destroy infrastructure
cd infra
terraform destroy
```

## Troubleshooting

**Glue job fails:**
- Check CloudWatch logs: `aws logs tail /aws-glue/jobs/output`
- Verify IAM permissions
- Ensure Glue script exists in S3

**Athena returns no results:**
- Repair partitions: `MSCK REPAIR TABLE transformed;`
- Verify Glue crawler completed successfully
- Check transformed data exists in S3

**S3 bucket name already exists:**
- Bucket names must be globally unique
- Change `project_name` in `infra/variables.tf`

