# AWS Glue Transformation Script

This directory contains the PySpark ETL script for transforming clickstream data.

## Script: clickstream_transform.py

**Purpose:** Transforms raw JSON clickstream events to optimized Parquet format with data cleaning and enrichment.

## Transformations Performed

### 1. Format Conversion
- **Input:** Raw JSON files from S3 (Kinesis Firehose output)
- **Output:** Columnar Parquet format (60-80% size reduction)
- **Partitioning:** By year/month/day

### 2. Field Removal
Removes sensitive/unnecessary fields:
- `user_agent`
- `ip_address`
- `additional_data`

### 3. Data Enrichment
Adds new fields:
- `processed_timestamp` - Job execution timestamp
- `year`, `month`, `day` - Partition fields
- `hour` - Hour of event
- `event_date` - Date of event
- `event_category` - Categorized event type (browsing/cart/conversion/engagement)
- `event_sequence` - Event number within session
- `is_session_start` - Boolean flag for first event in session

### 4. Data Cleaning
- Validates required fields (`event_id`, `user_id`, `event_type`, `timestamp`)
- Removes corrupt/invalid records
- Handles null values
- Logs data quality metrics

## How to Run

### Via AWS Glue Console
1. Navigate to AWS Glue Console
2. Go to ETL Jobs
3. Select `clickstream-pipeline-transform-job`
4. Click "Run job"

### Via AWS CLI

```bash
# Start job
aws glue start-job-run --job-name clickstream-pipeline-transform-job

# Check status
aws glue get-job-runs --job-name clickstream-pipeline-transform-job --max-results 1

# View logs
aws logs tail /aws-glue/jobs/output --follow
```

### Via Terraform (after infrastructure deployment)

```bash
# Get job name from Terraform output
JOB_NAME=$(terraform -chdir=../infra output -raw glue_job_name)

# Run job
aws glue start-job-run --job-name ${JOB_NAME}
```

## Job Configuration

The Glue job receives these parameters from Terraform:

- `--SOURCE_BUCKET` - S3 bucket containing raw JSON data
- `--TARGET_BUCKET` - S3 bucket for transformed Parquet data
- `--DATABASE_NAME` - Glue database name

**Resource allocation:**
- Glue Version: 4.0
- Worker Type: G.1X (4 vCPU, 16 GB memory)
- Number of Workers: 2
- Timeout: 60 minutes

## Input Data Schema

Expected JSON structure:

```json
{
  "event_id": "evt_001",
  "user_id": "user_12345",
  "session_id": "session_abc123",
  "event_type": "product_view",
  "timestamp": "2025-12-23T10:15:30.123Z",
  "page_url": "https://example.com/products/item",
  "product_id": "prod_001",
  "product_name": "Product Name",
  "product_category": "Electronics",
  "price": 99.99,
  "quantity": 1,
  "device_type": "desktop",
  "referrer": "https://google.com"
}
```

## Output Data Schema

Parquet files with schema:

```
event_id: string
user_id: string
session_id: string
event_type: string
timestamp: string
page_url: string
product_id: string
product_name: string
product_category: string
price: double
quantity: integer
device_type: string
referrer: string
processed_timestamp: timestamp
year: string
month: string
day: string
hour: integer
event_date: date
event_category: string
event_sequence: integer
is_session_start: boolean
has_product_data: boolean
has_price_data: boolean
```

## Output Location

```
s3://[transformed-bucket]/transformed/
  year=2025/
    month=12/
      day=23/
        part-00000.snappy.parquet
        part-00001.snappy.parquet
        ...
```

## Monitoring

**CloudWatch Logs:**
- Log Group: `/aws-glue/jobs/output`
- Includes job execution details, record counts, and error messages

**Metrics displayed:**
- Total records processed
- Distinct users
- Distinct sessions
- Event type distribution

## Local Development (Optional)

To test locally with PySpark:

```bash
# Install dependencies
pip install pyspark boto3

# Set AWS credentials
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret

# Run locally (requires modifications for local paths)
python clickstream_transform.py
```

Note: AWS Glue uses specific libraries (`awsglue`) that are only available in the Glue environment.

## Troubleshooting

**Job fails immediately:**
- Check CloudWatch logs for detailed error messages
- Verify IAM role has permissions to read from source bucket and write to target bucket
- Ensure source bucket contains valid JSON files

**No output data:**
- Verify input data exists in `s3://[raw-bucket]/raw/`
- Check for corrupt JSON records (logged to errors bucket)
- Verify target bucket permissions

**Slow performance:**
- Increase number of workers in `infra/glue.tf`
- Change worker type to G.2X for more resources
- Check if data is properly partitioned

