"""
AWS Glue ETL Job: Clickstream Data Transformation
Transforms raw JSON clickstream data to optimized Parquet format
"""

import sys
from datetime import datetime
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.types import *

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'SOURCE_BUCKET',
    'TARGET_BUCKET',
    'DATABASE_NAME'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
SOURCE_BUCKET = args['SOURCE_BUCKET']
TARGET_BUCKET = args['TARGET_BUCKET']
DATABASE_NAME = args['DATABASE_NAME']

SOURCE_PATH = f"s3://{SOURCE_BUCKET}/raw/"
TARGET_PATH = f"s3://{TARGET_BUCKET}/transformed/"

print(f"Starting transformation job: {args['JOB_NAME']}")
print(f"Source: {SOURCE_PATH}")
print(f"Target: {TARGET_PATH}")

# Define schema for clickstream events
clickstream_schema = StructType([
    StructField("event_id", StringType(), False),
    StructField("user_id", StringType(), False),
    StructField("session_id", StringType(), True),
    StructField("event_type", StringType(), False),
    StructField("timestamp", StringType(), False),
    StructField("page_url", StringType(), True),
    StructField("product_id", StringType(), True),
    StructField("product_name", StringType(), True),
    StructField("product_category", StringType(), True),
    StructField("price", DoubleType(), True),
    StructField("quantity", IntegerType(), True),
    StructField("user_agent", StringType(), True),
    StructField("ip_address", StringType(), True),
    StructField("device_type", StringType(), True),
    StructField("referrer", StringType(), True),
    StructField("additional_data", StringType(), True)
])

# Read raw JSON data
print("Reading raw JSON data...")
raw_df = spark.read \
    .option("multiLine", "true") \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .json(SOURCE_PATH)

print(f"Total records read: {raw_df.count()}")

# Filter out corrupt records
if "_corrupt_record" in raw_df.columns:
    corrupt_count = raw_df.filter(F.col("_corrupt_record").isNotNull()).count()
    print(f"Corrupt records found: {corrupt_count}")
    
    # Save corrupt records for analysis
    if corrupt_count > 0:
        raw_df.filter(F.col("_corrupt_record").isNotNull()) \
            .select("_corrupt_record") \
            .write \
            .mode("append") \
            .text(f"s3://{SOURCE_BUCKET}/errors/corrupt_records/")
    
    # Keep only valid records
    raw_df = raw_df.filter(F.col("_corrupt_record").isNull()).drop("_corrupt_record")

# Data validation: Check required fields
print("Validating required fields...")
required_fields = ["event_id", "user_id", "event_type", "timestamp"]
for field in required_fields:
    if field in raw_df.columns:
        null_count = raw_df.filter(F.col(field).isNull()).count()
        if null_count > 0:
            print(f"Warning: {null_count} records have null {field}")
            # Remove records with null required fields
            raw_df = raw_df.filter(F.col(field).isNotNull())

print(f"Valid records after filtering: {raw_df.count()}")

# Transform data
print("Applying transformations...")

transformed_df = raw_df \
    .withColumn("processed_timestamp", F.current_timestamp()) \
    .withColumn("timestamp_parsed", F.to_timestamp(F.col("timestamp"))) \
    .withColumn("year", F.year(F.col("timestamp_parsed"))) \
    .withColumn("month", F.lpad(F.month(F.col("timestamp_parsed")).cast("string"), 2, "0")) \
    .withColumn("day", F.lpad(F.dayofmonth(F.col("timestamp_parsed")).cast("string"), 2, "0")) \
    .withColumn("hour", F.hour(F.col("timestamp_parsed"))) \
    .withColumn("event_date", F.to_date(F.col("timestamp_parsed")))

# Remove sensitive/unnecessary fields
columns_to_drop = ["user_agent", "ip_address", "additional_data", "timestamp_parsed"]
for col in columns_to_drop:
    if col in transformed_df.columns:
        transformed_df = transformed_df.drop(col)

# Add data quality metrics
transformed_df = transformed_df \
    .withColumn("has_product_data", 
                F.when(F.col("product_id").isNotNull(), True).otherwise(False)) \
    .withColumn("has_price_data",
                F.when(F.col("price").isNotNull(), True).otherwise(False))

# Data enrichment: Categorize events
transformed_df = transformed_df.withColumn(
    "event_category",
    F.when(F.col("event_type").isin(["product_view", "category_view", "search"]), "browsing")
    .when(F.col("event_type").isin(["add_to_cart", "remove_from_cart"]), "cart")
    .when(F.col("event_type").isin(["checkout_start", "payment_info", "purchase"]), "conversion")
    .when(F.col("event_type").isin(["page_view", "login", "logout", "signup"]), "engagement")
    .otherwise("other")
)

# Calculate session metrics
print("Calculating session metrics...")
session_window = Window.partitionBy("session_id").orderBy("timestamp")
transformed_df = transformed_df \
    .withColumn("event_sequence", F.row_number().over(session_window)) \
    .withColumn("is_session_start", 
                F.when(F.col("event_sequence") == 1, True).otherwise(False))

# Show sample of transformed data
print("Sample transformed data:")
transformed_df.show(5, truncate=False)

# Print schema
print("Transformed schema:")
transformed_df.printSchema()

# Write to S3 in Parquet format with partitioning
print(f"Writing transformed data to {TARGET_PATH}")
transformed_df.write \
    .mode("append") \
    .partitionBy("year", "month", "day") \
    .parquet(TARGET_PATH)

# Calculate and log statistics
total_records = transformed_df.count()
distinct_users = transformed_df.select("user_id").distinct().count()
distinct_sessions = transformed_df.select("session_id").distinct().count()
event_types = transformed_df.groupBy("event_type").count().collect()

print("=" * 60)
print("TRANSFORMATION SUMMARY")
print("=" * 60)
print(f"Total records processed: {total_records}")
print(f"Distinct users: {distinct_users}")
print(f"Distinct sessions: {distinct_sessions}")
print("\nEvent type distribution:")
for row in event_types:
    print(f"  {row['event_type']}: {row['count']}")
print("=" * 60)

# Commit job
job.commit()

print("Job completed successfully!")

