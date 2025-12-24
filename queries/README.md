# Athena SQL Queries

Sample SQL queries for analyzing clickstream data using Amazon Athena.

## File: athena_queries.sql

Contains 12 pre-built analytical queries demonstrating various analysis patterns.

## How to Run Queries

### Via AWS Athena Console

1. Navigate to Amazon Athena Console
2. Select workgroup: `clickstream-pipeline-workgroup`
3. Select database: `clickstream_db`
4. Copy and paste queries from `athena_queries.sql`
5. Click "Run query"
6. Results appear in the results pane

### Via AWS CLI

```bash
# Get Athena configuration
WORKGROUP=$(cat ../terraform-outputs.json | jq -r '.athena_workgroup_name.value')
RESULTS_BUCKET=$(cat ../terraform-outputs.json | jq -r '.athena_results_bucket_name.value')

# Run a query
aws athena start-query-execution \
  --query-string "SELECT event_type, COUNT(*) as count FROM transformed GROUP BY event_type;" \
  --query-execution-context "Database=clickstream_db" \
  --result-configuration "OutputLocation=s3://${RESULTS_BUCKET}/" \
  --work-group ${WORKGROUP}

# Get query results (replace QUERY_ID)
aws athena get-query-results --query-execution-id QUERY_ID
```

## Available Queries

### 1. Event Type Distribution
Shows count of each event type with percentages.

```sql
SELECT event_type, COUNT(*) as event_count
FROM transformed
GROUP BY event_type
ORDER BY event_count DESC;
```

### 2. Daily Active Users
Tracks daily active users over time with engagement metrics.

```sql
SELECT year, month, day, 
       COUNT(DISTINCT user_id) as daily_active_users,
       COUNT(*) as total_events
FROM transformed
GROUP BY year, month, day;
```

### 3. Product Performance
Analyzes product views, cart additions, and purchases with conversion rates.

```sql
SELECT product_id, product_name,
       SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END) as views,
       SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases
FROM transformed
WHERE product_id IS NOT NULL
GROUP BY product_id, product_name;
```

### 4. Hourly Activity Pattern
Shows user activity patterns by hour of day.

### 5. User Funnel Analysis
Tracks conversion funnel from browsing to purchase.

### 6. Top Referrer Sources
Identifies which referrer sources drive the most traffic.

### 7. Device Type Analysis
Compares user behavior across different device types.

### 8. Revenue Analysis
Calculates revenue metrics from purchase events.

### 9. Session Duration Analysis
Analyzes average session duration.

### 10. Category Performance
Analyzes performance by product category.

### 11. New vs Returning User Behavior
Compares behavior between first-time and returning users.

### 12. Real-time Event Monitoring
Shows latest events for debugging/monitoring.

## Maintenance Queries

**Repair partitions after new data:**
```sql
MSCK REPAIR TABLE transformed;
```

**Show all partitions:**
```sql
SHOW PARTITIONS transformed;
```

**Check data quality:**
```sql
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT event_id) as unique_events,
    COUNT(DISTINCT user_id) as unique_users
FROM transformed;
```

## Query Optimization Tips

1. **Always filter by partitions** to reduce data scanned:
```sql
WHERE year = '2025' AND month = '12' AND day = '23'
```

2. **Use appropriate data types** in predicates
3. **LIMIT results** for exploratory queries
4. **Use columnar projections** - select only needed columns
5. **Leverage Parquet's columnar format** for aggregations

## Cost Considerations

Athena charges $5 per TB of data scanned:

- **Good:** `SELECT product_id, COUNT(*) FROM transformed WHERE year='2025' GROUP BY product_id;`
  - Scans only product_id column and year=2025 partition

- **Bad:** `SELECT * FROM transformed;`
  - Scans entire table (all partitions, all columns)

## Sample Output

**Event Type Distribution:**
```
event_type      | count
----------------|-------
product_view    | 1,234
page_view       | 987
add_to_cart     | 456
purchase        | 123
```

**Daily Active Users:**
```
year | month | day | daily_active_users
-----|-------|-----|-------------------
2025 | 12    | 23  | 5,432
2025 | 12    | 22  | 5,198
```

## Troubleshooting

**"Table not found" error:**
- Ensure Glue crawler has run: `aws glue start-crawler --name clickstream-pipeline-crawler`
- Check table exists: `SHOW TABLES;`

**"No data" returned:**
- Verify data exists in S3 transformed bucket
- Run `MSCK REPAIR TABLE transformed;` to update partitions
- Check date filters match data partitions

**Slow queries:**
- Add partition filters (year, month, day)
- Select only required columns
- Limit results for testing

**"Access Denied" error:**
- Verify IAM permissions for Athena to read S3 buckets
- Check S3 bucket policies

## Additional Resources

- [Athena SQL Reference](https://docs.aws.amazon.com/athena/latest/ug/ddl-sql-reference.html)
- [Athena Performance Tuning](https://docs.aws.amazon.com/athena/latest/ug/performance-tuning.html)
- [Partitioning Data](https://docs.aws.amazon.com/athena/latest/ug/partitions.html)

