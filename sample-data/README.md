# Sample Clickstream Data

This directory contains sample JSON clickstream events for testing the pipeline.

## File: sample_events.json

**Format:** JSON array containing 25 sample e-commerce clickstream events

**Event Types Included:**
- `page_view` - User views a page
- `product_view` - User views a product
- `add_to_cart` - User adds item to cart
- `remove_from_cart` - User removes item from cart
- `checkout_start` - User begins checkout
- `payment_info` - User enters payment information
- `purchase` - User completes purchase
- `search` - User performs search
- `login` - User logs in
- `logout` - User logs out
- `signup` - User creates account
- `category_view` - User views a category

## How to Use

### Upload to S3 (Testing Pipeline)

```bash
# Get raw bucket name from Terraform outputs
RAW_BUCKET=$(cat ../terraform-outputs.json | jq -r '.raw_bucket_name.value')

# Set date for partitioning
YEAR=$(date -u +"%Y")
MONTH=$(date -u +"%m")
DAY=$(date -u +"%d")

# Upload sample data
aws s3 cp sample_events.json \
  "s3://${RAW_BUCKET}/raw/year=${YEAR}/month=${MONTH}/day=${DAY}/sample_events.json"

# Verify upload
aws s3 ls "s3://${RAW_BUCKET}/raw/year=${YEAR}/month=${MONTH}/day=${DAY}/"
```

### Send Events via Kinesis Firehose

Use the `../test-event-sender.py` script to send events through Kinesis Firehose:

```bash
pip3 install boto3
python3 ../test-event-sender.py
```

## Sample Event Structure

```json
{
  "event_id": "evt_001",
  "user_id": "user_12345",
  "session_id": "session_abc123",
  "event_type": "product_view",
  "timestamp": "2025-12-23T10:15:30.123Z",
  "page_url": "https://example.com/products/laptop-pro",
  "product_id": "prod_001",
  "product_name": "Laptop Pro 15",
  "product_category": "Electronics",
  "price": 1299.99,
  "quantity": 1,
  "device_type": "desktop",
  "referrer": "https://google.com"
}
```

## Sample Data Statistics

- **Total Events:** 25
- **Unique Users:** 5
- **Unique Sessions:** 6
- **Event Types:** 12 different types
- **Products:** 5 different products
- **Categories:** Electronics, Clothing, Furniture

## Event Flow Examples

**User Session 1 (user_12345):**
1. Page view → Homepage
2. Product view → Laptop Pro 15
3. Add to cart → Laptop Pro 15
4. Checkout start
5. Payment info
6. Purchase → Laptop Pro 15 ($1,299.99)

**User Session 2 (user_67890):**
1. Page view → Homepage
2. Search → "wireless headphones"
3. Product view → Wireless Headphones Pro
4. Add to cart → Wireless Headphones Pro
5. Remove from cart → Wireless Headphones Pro (abandoned)

## Generating More Data

To generate additional test data, modify and use the `test-event-sender.py` script:

```python
# Generate N sessions with random events
python3 ../test-event-sender.py
# Follow prompts to generate sessions
```

## After Uploading Data

1. **Run Glue Job** to transform data:
```bash
aws glue start-job-run --job-name clickstream-pipeline-transform-job
```

2. **Run Glue Crawler** to catalog data:
```bash
aws glue start-crawler --name clickstream-pipeline-crawler
```

3. **Query with Athena**:
```sql
SELECT event_type, COUNT(*) as count
FROM transformed
GROUP BY event_type;
```

## Expected Results

After processing, you should see:
- Raw data in S3: `s3://[raw-bucket]/raw/year=2025/month=12/day=23/`
- Transformed data in S3: `s3://[transformed-bucket]/transformed/year=2025/month=12/day=23/`
- Table in Athena: `clickstream_db.transformed`

## Notes

- All timestamps in the sample data use ISO 8601 format with UTC timezone
- Product prices are in USD
- Device types: desktop, mobile, tablet
- All user IDs and session IDs are fictional for testing purposes

