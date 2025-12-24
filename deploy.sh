#!/bin/bash

# =============================================================================
# Clickstream Pipeline Deployment Script
# =============================================================================
# This script automates the deployment of the clickstream analytics pipeline
# Usage: ./deploy.sh [--destroy]
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="${PROJECT_NAME:-clickstream-pipeline}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo ""
    echo "=============================================="
    echo "  Clickstream Pipeline Deployment"
    echo "=============================================="
    echo "  Project: $PROJECT_NAME"
    echo "  Environment: $ENVIRONMENT"
    echo "  Region: $AWS_REGION"
    echo "=============================================="
    echo ""
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for required tools
    command -v aws >/dev/null 2>&1 || { log_error "AWS CLI is not installed. Aborting."; exit 1; }
    command -v terraform >/dev/null 2>&1 || { log_error "Terraform is not installed. Aborting."; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_error "jq is not installed. Aborting."; exit 1; }
    
    # Check AWS credentials
    aws sts get-caller-identity >/dev/null 2>&1 || { log_error "AWS credentials not configured. Run 'aws configure'. Aborting."; exit 1; }
    
    log_success "All prerequisites met"
}

deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd infra
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Plan
    log_info "Planning infrastructure changes..."
    terraform plan \
        -var="project_name=${PROJECT_NAME}" \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${AWS_REGION}" \
        -out=tfplan
    
    # Ask for confirmation
    read -p "Do you want to apply these changes? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_warning "Deployment cancelled by user"
        exit 0
    fi
    
    # Apply
    log_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Save outputs
    log_info "Saving Terraform outputs..."
    terraform output -json > ../terraform-outputs.json
    
    cd ..
    
    log_success "Infrastructure deployed successfully"
}

upload_sample_data() {
    log_info "Uploading sample data..."
    
    # Get bucket name from Terraform output
    RAW_BUCKET=$(jq -r '.raw_bucket_name.value' terraform-outputs.json)
    
    if [ -z "$RAW_BUCKET" ] || [ "$RAW_BUCKET" = "null" ]; then
        log_error "Could not retrieve bucket name from Terraform outputs"
        return 1
    fi
    
    # Upload sample events
    CURRENT_DATE=$(date -u +"%Y-%m-%d")
    YEAR=$(date -u +"%Y")
    MONTH=$(date -u +"%m")
    DAY=$(date -u +"%d")
    
    S3_PATH="s3://${RAW_BUCKET}/raw/year=${YEAR}/month=${MONTH}/day=${DAY}/sample_events.json"
    
    log_info "Uploading to ${S3_PATH}"
    aws s3 cp sample-data/sample_events.json "$S3_PATH"
    
    log_success "Sample data uploaded successfully"
}

run_glue_job() {
    log_info "Starting Glue ETL job..."
    
    JOB_NAME="${PROJECT_NAME}-transform-job"
    
    # Start job
    RUN_ID=$(aws glue start-job-run \
        --job-name "$JOB_NAME" \
        --region "$AWS_REGION" \
        --query 'JobRunId' \
        --output text)
    
    log_info "Job started with Run ID: $RUN_ID"
    log_info "Waiting for job to complete (this may take a few minutes)..."
    
    # Wait for job completion
    while true; do
        STATUS=$(aws glue get-job-run \
            --job-name "$JOB_NAME" \
            --run-id "$RUN_ID" \
            --region "$AWS_REGION" \
            --query 'JobRun.JobRunState' \
            --output text)
        
        if [ "$STATUS" = "SUCCEEDED" ]; then
            log_success "Glue job completed successfully"
            break
        elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "STOPPED" ] || [ "$STATUS" = "TIMEOUT" ]; then
            log_error "Glue job failed with status: $STATUS"
            log_info "Check CloudWatch logs for details: /aws-glue/jobs/output"
            return 1
        else
            echo -n "."
            sleep 10
        fi
    done
}

run_glue_crawler() {
    log_info "Starting Glue crawler..."
    
    CRAWLER_NAME="${PROJECT_NAME}-crawler"
    
    # Start crawler
    aws glue start-crawler \
        --name "$CRAWLER_NAME" \
        --region "$AWS_REGION" 2>/dev/null || {
        log_warning "Crawler might already be running or just finished"
    }
    
    log_info "Waiting for crawler to complete..."
    
    # Wait for crawler completion
    sleep 5
    while true; do
        STATE=$(aws glue get-crawler \
            --name "$CRAWLER_NAME" \
            --region "$AWS_REGION" \
            --query 'Crawler.State' \
            --output text)
        
        if [ "$STATE" = "READY" ]; then
            # Check last crawl status
            LAST_STATUS=$(aws glue get-crawler \
                --name "$CRAWLER_NAME" \
                --region "$AWS_REGION" \
                --query 'Crawler.LastCrawl.Status' \
                --output text)
            
            if [ "$LAST_STATUS" = "SUCCEEDED" ]; then
                log_success "Crawler completed successfully"
                break
            else
                log_error "Crawler failed with status: $LAST_STATUS"
                return 1
            fi
        else
            echo -n "."
            sleep 10
        fi
    done
}

test_athena_query() {
    log_info "Running test Athena query..."
    
    WORKGROUP=$(jq -r '.athena_workgroup_name.value' terraform-outputs.json)
    RESULTS_BUCKET=$(jq -r '.athena_results_bucket_name.value' terraform-outputs.json)
    
    # Simple count query
    QUERY="SELECT event_type, COUNT(*) as count FROM transformed GROUP BY event_type;"
    
    QUERY_ID=$(aws athena start-query-execution \
        --query-string "$QUERY" \
        --query-execution-context "Database=clickstream_db" \
        --result-configuration "OutputLocation=s3://${RESULTS_BUCKET}/" \
        --work-group "$WORKGROUP" \
        --region "$AWS_REGION" \
        --query 'QueryExecutionId' \
        --output text)
    
    log_info "Query started with ID: $QUERY_ID"
    log_info "Waiting for query to complete..."
    
    # Wait for query completion
    while true; do
        STATUS=$(aws athena get-query-execution \
            --query-execution-id "$QUERY_ID" \
            --region "$AWS_REGION" \
            --query 'QueryExecution.Status.State' \
            --output text)
        
        if [ "$STATUS" = "SUCCEEDED" ]; then
            log_success "Query completed successfully"
            
            # Show results
            log_info "Query results:"
            aws athena get-query-results \
                --query-execution-id "$QUERY_ID" \
                --region "$AWS_REGION" \
                --output table
            break
        elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "CANCELLED" ]; then
            log_error "Query failed with status: $STATUS"
            return 1
        else
            echo -n "."
            sleep 3
        fi
    done
}

print_summary() {
    log_success "Deployment completed successfully!"
    echo ""
    echo "=============================================="
    echo "  Deployment Summary"
    echo "=============================================="
    echo ""
    
    if [ -f terraform-outputs.json ]; then
        echo "📦 S3 Buckets:"
        echo "  - Raw Data: $(jq -r '.raw_bucket_name.value' terraform-outputs.json)"
        echo "  - Transformed: $(jq -r '.transformed_bucket_name.value' terraform-outputs.json)"
        echo "  - Athena Results: $(jq -r '.athena_results_bucket_name.value' terraform-outputs.json)"
        echo ""
        echo "🔄 Kinesis Firehose:"
        echo "  - Stream: $(jq -r '.firehose_stream_name.value' terraform-outputs.json)"
        echo ""
        echo "✨ AWS Glue:"
        echo "  - Database: $(jq -r '.glue_database_name.value' terraform-outputs.json)"
        echo "  - Job: $(jq -r '.glue_job_name.value' terraform-outputs.json)"
        echo "  - Crawler: $(jq -r '.glue_crawler_name.value' terraform-outputs.json)"
        echo ""
        echo "🔍 Athena:"
        echo "  - Workgroup: $(jq -r '.athena_workgroup_name.value' terraform-outputs.json)"
        echo ""
    fi
    
    echo "=============================================="
    echo ""
    echo "Next Steps:"
    echo "  1. Send events to Kinesis Firehose"
    echo "  2. Run Glue job to transform data"
    echo "  3. Run crawler to catalog data"
    echo "  4. Query with Athena"
    echo ""
    echo "Useful Commands:"
    echo "  # Run Glue job"
    echo "  aws glue start-job-run --job-name ${PROJECT_NAME}-transform-job"
    echo ""
    echo "  # Run crawler"
    echo "  aws glue start-crawler --name ${PROJECT_NAME}-crawler"
    echo ""
    echo "  # Query with Athena"
    echo "  aws athena start-query-execution \\"
    echo "    --query-string 'SELECT * FROM transformed LIMIT 10;' \\"
    echo "    --query-execution-context 'Database=clickstream_db' \\"
    echo "    --result-configuration 'OutputLocation=s3://$(jq -r '.athena_results_bucket_name.value' terraform-outputs.json)/'"
    echo ""
    echo "=============================================="
}

destroy_infrastructure() {
    log_warning "Destroying infrastructure..."
    
    read -p "Are you sure you want to destroy all resources? This cannot be undone. (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Destruction cancelled by user"
        exit 0
    fi
    
    cd infra
    
    # Empty S3 buckets first
    log_info "Emptying S3 buckets..."
    for bucket in $(terraform output -json | jq -r '.[] | select(.value | strings) | select(.value | startswith("clickstream-")) | .value'); do
        log_info "Emptying bucket: ${bucket}"
        aws s3 rm "s3://${bucket}" --recursive --region "$AWS_REGION" || true
    done
    
    # Destroy infrastructure
    log_info "Destroying Terraform resources..."
    terraform destroy \
        -var="project_name=${PROJECT_NAME}" \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${AWS_REGION}" \
        -auto-approve
    
    cd ..
    
    # Clean up local files
    rm -f terraform-outputs.json
    
    log_success "Infrastructure destroyed successfully"
}

# Main execution
main() {
    print_banner
    
    # Check for destroy flag
    if [ "$1" = "--destroy" ]; then
        check_prerequisites
        destroy_infrastructure
        exit 0
    fi
    
    # Normal deployment flow
    check_prerequisites
    deploy_infrastructure
    
    # Ask if user wants to run the full pipeline
    echo ""
    read -p "Do you want to upload sample data and run the pipeline? (yes/no): " run_pipeline
    
    if [ "$run_pipeline" = "yes" ]; then
        upload_sample_data
        run_glue_job
        run_glue_crawler
        test_athena_query
    fi
    
    echo ""
    print_summary
}

# Run main function
main "$@"

