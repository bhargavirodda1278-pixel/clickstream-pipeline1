#!/usr/bin/env python3
"""
Test Event Sender for Kinesis Firehose
Sends sample clickstream events to test the pipeline
"""

import boto3
import json
import random
import time
from datetime import datetime, timezone
import uuid

# Configuration
FIREHOSE_STREAM_NAME = "clickstream-pipeline-stream"  # Update with your stream name
AWS_REGION = "us-east-1"  # Update with your region

# Initialize Firehose client
firehose = boto3.client('firehose', region_name=AWS_REGION)

# Sample data
EVENT_TYPES = [
    "page_view", "product_view", "add_to_cart", "remove_from_cart",
    "checkout_start", "payment_info", "purchase", "search",
    "login", "logout", "signup", "category_view"
]

PRODUCTS = [
    {"id": "prod_001", "name": "Laptop Pro 15", "category": "Electronics", "price": 1299.99},
    {"id": "prod_002", "name": "Wireless Headphones Pro", "category": "Electronics", "price": 249.99},
    {"id": "prod_003", "name": "Blue Cotton T-Shirt", "category": "Clothing", "price": 29.99},
    {"id": "prod_004", "name": "Slim Fit Jeans", "category": "Clothing", "price": 79.99},
    {"id": "prod_005", "name": "Ergonomic Office Chair", "category": "Furniture", "price": 399.99},
    {"id": "prod_006", "name": "Stainless Steel Water Bottle", "category": "Home", "price": 24.99},
    {"id": "prod_007", "name": "Yoga Mat Premium", "category": "Sports", "price": 49.99},
    {"id": "prod_008", "name": "Smart Watch Pro", "category": "Electronics", "price": 299.99},
]

DEVICE_TYPES = ["desktop", "mobile", "tablet"]
REFERRERS = ["https://google.com", "https://facebook.com", "https://twitter.com", 
             "https://instagram.com", "https://bing.com", "direct"]

def generate_event(user_id, session_id):
    """Generate a random clickstream event"""
    event_type = random.choice(EVENT_TYPES)
    event = {
        "event_id": f"evt_{uuid.uuid4().hex[:12]}",
        "user_id": user_id,
        "session_id": session_id,
        "event_type": event_type,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "device_type": random.choice(DEVICE_TYPES),
    }
    
    # Add product data for relevant events
    if event_type in ["product_view", "add_to_cart", "remove_from_cart", "purchase"]:
        product = random.choice(PRODUCTS)
        event.update({
            "product_id": product["id"],
            "product_name": product["name"],
            "product_category": product["category"],
            "price": product["price"],
        })
        
        if event_type in ["add_to_cart", "purchase"]:
            event["quantity"] = random.randint(1, 3)
    
    # Add page URL
    if event_type == "product_view":
        event["page_url"] = f"https://example.com/products/{event.get('product_id', 'unknown')}"
    elif event_type == "category_view":
        product = random.choice(PRODUCTS)
        event["page_url"] = f"https://example.com/categories/{product['category'].lower()}"
    elif event_type == "search":
        event["page_url"] = "https://example.com/search?q=" + random.choice(["laptop", "headphones", "shirt", "chair"])
    else:
        event["page_url"] = "https://example.com/"
    
    # Add referrer occasionally
    if random.random() > 0.5:
        event["referrer"] = random.choice(REFERRERS)
    
    return event

def send_event(event):
    """Send event to Kinesis Firehose"""
    try:
        response = firehose.put_record(
            DeliveryStreamName=FIREHOSE_STREAM_NAME,
            Record={'Data': json.dumps(event) + '\n'}
        )
        return response
    except Exception as e:
        print(f"Error sending event: {e}")
        return None

def generate_session(user_id):
    """Generate a realistic user session with multiple events"""
    session_id = f"session_{uuid.uuid4().hex[:12]}"
    num_events = random.randint(3, 10)
    
    print(f"\n{'='*60}")
    print(f"Generating session for user: {user_id}")
    print(f"Session ID: {session_id}")
    print(f"Events in session: {num_events}")
    print(f"{'='*60}\n")
    
    for i in range(num_events):
        event = generate_event(user_id, session_id)
        print(f"Event {i+1}/{num_events}: {event['event_type']}")
        
        response = send_event(event)
        if response:
            print(f"  ✓ Sent successfully (RecordId: {response['RecordId'][:20]}...)")
        else:
            print(f"  ✗ Failed to send")
        
        # Wait a bit between events to simulate real user behavior
        time.sleep(random.uniform(0.5, 2.0))
    
    print(f"\nSession completed: {num_events} events sent")

def main():
    print("\n" + "="*60)
    print("Clickstream Event Generator")
    print("="*60)
    print(f"Target: {FIREHOSE_STREAM_NAME}")
    print(f"Region: {AWS_REGION}")
    print("="*60 + "\n")
    
    try:
        # Test connection
        response = firehose.describe_delivery_stream(
            DeliveryStreamName=FIREHOSE_STREAM_NAME
        )
        print(f"✓ Connected to Firehose stream")
        print(f"  Status: {response['DeliveryStreamDescription']['DeliveryStreamStatus']}")
        print()
        
        # Generate sessions
        num_sessions = int(input("How many sessions do you want to generate? (default: 5): ") or "5")
        
        for i in range(num_sessions):
            user_id = f"user_{random.randint(10000, 99999)}"
            generate_session(user_id)
            
            if i < num_sessions - 1:
                print(f"\nWaiting 2 seconds before next session...\n")
                time.sleep(2)
        
        print("\n" + "="*60)
        print(f"✓ All sessions generated successfully!")
        print(f"  Total sessions: {num_sessions}")
        print("="*60 + "\n")
        
        print("Next steps:")
        print("  1. Wait ~5 minutes for data to appear in S3")
        print("  2. Run the Glue job to transform the data")
        print("  3. Run the Glue crawler to catalog the data")
        print("  4. Query the data with Athena")
        print()
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nMake sure:")
        print("  1. AWS credentials are configured")
        print("  2. Firehose stream name is correct")
        print("  3. You have permissions to write to Firehose")
        print()

if __name__ == "__main__":
    main()

