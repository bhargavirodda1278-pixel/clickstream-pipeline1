# Clickstream Data Pipeline

A serverless data engineering pipeline for processing clickstream events on AWS.

## Architecture

```
Kinesis Firehose → S3 (Raw JSON) → Glue Job → S3 (Parquet) → Glue Crawler → Athena
```

**Components:**

1. **Kinesis Data Firehose** - Ingests JSON events and writes to S3 with date partitioning (`s3://bucket/raw/year=YYYY/month=MM/day=DD/`)
2. **AWS Glue Job** - Transforms JSON to Parquet format, removes unnecessary fields, enriches data
3. **AWS Glue Crawler** - Catalogs the transformed Parquet data in Glue Data Catalog
4. **Amazon Athena** - Queries the cataloged data using SQL

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.0
- Python 3.9+
- jq

## Deployment

### Option 1: Automated (Recommended)

```bash
# Set environment variables (optional)
export AWS_REGION="us-east-1"
export PROJECT_NAME="clickstream-pipeline"

# Deploy everything
./deploy.sh
```

### Option 2: Manual

```bash
cd infra
terraform init
terraform plan
terraform apply
terraform output -json > ../terraform-outputs.json
```

## Infrastructure as Code

**Tool:** Terraform

**Resources created:**
- 1 Kinesis Data Firehose delivery stream
- 5 S3 buckets (raw, transformed, scripts, athena-results, errors)
- 1 Glue database, job, and crawler
- 1 Athena workgroup
- IAM roles and policies

## Data Transformation

**Transformations performed:**
- **Format conversion:** JSON → Parquet
- **Field removal:** `user_agent`, `ip_address`, `additional_data`
- **Data enrichment:** `processed_timestamp`, `year`, `month`, `day`, `event_category`
- **Data cleaning:** Validates required fields, removes corrupt records

**Script location:** `glue/clickstream_transform.py`

## Glue Crawler & Athena

**Cataloging:** The Glue Crawler scans transformed Parquet data in S3 (`s3://bucket/transformed/`) and:
- Discovers schema (columns and data types)
- Detects partitions (`year`, `month`, `day`)
- Creates/updates the `transformed` table in Glue Data Catalog

**Sample Athena Queries:**

```sql
-- Event type distribution
SELECT event_type, COUNT(*) as event_count
FROM transformed
GROUP BY event_type
ORDER BY event_count DESC;

-- Daily active users
SELECT year, month, day, 
       COUNT(DISTINCT user_id) as daily_active_users
FROM transformed
GROUP BY year, month, day
ORDER BY year DESC, month DESC, day DESC;
```

Additional queries: `queries/athena_queries.sql`

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
```

### 3. Run Glue Crawler

```bash
aws glue start-crawler --name ${PROJECT_NAME}-crawler
```

### 4. Query with Athena

```bash
WORKGROUP=$(cat terraform-outputs.json | jq -r '.athena_workgroup_name.value')
RESULTS_BUCKET=$(cat terraform-outputs.json | jq -r '.athena_results_bucket_name.value')

aws athena start-query-execution \
  --query-string "SELECT * FROM transformed LIMIT 10;" \
  --query-execution-context "Database=clickstream_db" \
  --result-configuration "OutputLocation=s3://${RESULTS_BUCKET}/" \
  --work-group ${WORKGROUP}
```

## Project Structure

```
clickstream-pipeline/
├── infra/                      # Terraform IaC
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── s3.tf
│   ├── kinesis.tf
│   ├── glue.tf
│   ├── athena.tf
│   └── iam.tf
├── glue/
│   └── clickstream_transform.py
├── queries/
│   └── athena_queries.sql
├── sample-data/
│   └── sample_events.json
├── deploy.sh
└── README.md
```

## Cleanup

```bash
./deploy.sh --destroy
```

Or manually:

```bash
# Empty S3 buckets first
cd infra
terraform destroy
```
## AI Tooling Disclosure
This project was developed primarily through manual implementation, testing, and validation. AI tools were used only as reference resources to support research, explore alternative approaches, and verify best practices. All final code, IaC, ETL logic, and documentation were written, reviewed, and tested by me.

## AI Tools Referenced
Microsoft Copilot

Google Gemini

These tools were consulted for high‑level guidance and conceptual clarification. They were not used to generate final production code.

## How AI Supported the Work
## AI tools were used to:

- Explore example Terraform patterns for AWS services

- Review common PySpark ETL structures

- Validate IAM least‑privilege best practices

- Improve documentation structure

- Cross‑check conceptual approaches

### What Was Done Manually
- All Terraform IaC

- PySpark transformation logic

- IAM policy design

- Glue Crawler + Athena configuration

- End‑to‑end pipeline testing

### All documentation and queries
This project was developed primarily through manual implementation, testing, and validation. AI tools were used only as reference resources to support research, explore alternative approaches, and verify best practices. All final code, IaC, ETL logic, and documentation were written, reviewed, and tested by me.

## License

MIT License

