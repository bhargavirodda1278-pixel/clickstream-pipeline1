-- ============================================================================
-- Clickstream Analytics - Athena SQL Queries
-- ============================================================================

-- Query 1: Event Type Distribution
-- Shows the count of each event type for today's data
SELECT 
    event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM transformed
WHERE year = CAST(year(current_date) AS VARCHAR)
  AND month = LPAD(CAST(month(current_date) AS VARCHAR), 2, '0')
  AND day = LPAD(CAST(day(current_date) AS VARCHAR), 2, '0')
GROUP BY event_type
ORDER BY event_count DESC;

-- Query 2: Daily Active Users (Last 30 Days)
-- Tracks daily active users and engagement metrics
SELECT 
    year,
    month,
    day,
    CONCAT(year, '-', month, '-', day) as date,
    COUNT(DISTINCT user_id) as daily_active_users,
    COUNT(*) as total_events,
    COUNT(DISTINCT session_id) as total_sessions,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT user_id), 2) as avg_events_per_user,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT session_id), 2) as avg_events_per_session
FROM transformed
GROUP BY year, month, day
ORDER BY year DESC, month DESC, day DESC
LIMIT 30;

-- Query 3: Product Performance Analysis
-- Analyzes product views, cart additions, and purchases
SELECT 
    product_id,
    product_name,
    product_category,
    SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END) as views,
    SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) as cart_adds,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
    ROUND(
        SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END), 0), 
        2
    ) as view_to_cart_rate,
    ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END), 0), 
        2
    ) as cart_to_purchase_rate,
    ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END), 0), 
        2
    ) as overall_conversion_rate
FROM transformed
WHERE product_id IS NOT NULL
GROUP BY product_id, product_name, product_category
HAVING views > 5
ORDER BY purchases DESC, views DESC
LIMIT 50;

-- Query 4: Hourly Activity Pattern
-- Shows user activity patterns by hour of day
SELECT 
    hour,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    ROUND(AVG(CASE WHEN event_type = 'purchase' THEN 1.0 ELSE 0.0 END) * 100, 2) as purchase_rate
FROM transformed
WHERE year = CAST(year(current_date) AS VARCHAR)
  AND month = LPAD(CAST(month(current_date) AS VARCHAR), 2, '0')
  AND day = LPAD(CAST(day(current_date) AS VARCHAR), 2, '0')
GROUP BY hour
ORDER BY hour;

-- Query 5: User Funnel Analysis
-- Tracks conversion funnel from browsing to purchase
WITH funnel_events AS (
    SELECT 
        session_id,
        MAX(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END) as viewed_product,
        MAX(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) as added_to_cart,
        MAX(CASE WHEN event_type = 'checkout_start' THEN 1 ELSE 0 END) as started_checkout,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as completed_purchase
    FROM transformed
    WHERE year = CAST(year(current_date) AS VARCHAR)
      AND month = LPAD(CAST(month(current_date) AS VARCHAR), 2, '0')
      AND day = LPAD(CAST(day(current_date) AS VARCHAR), 2, '0')
    GROUP BY session_id
)
SELECT 
    'Product View' as stage,
    SUM(viewed_product) as sessions,
    100.0 as percentage,
    0 as drop_off_rate
FROM funnel_events
UNION ALL
SELECT 
    'Add to Cart' as stage,
    SUM(added_to_cart) as sessions,
    ROUND(SUM(added_to_cart) * 100.0 / NULLIF(SUM(viewed_product), 0), 2) as percentage,
    ROUND(100.0 - (SUM(added_to_cart) * 100.0 / NULLIF(SUM(viewed_product), 0)), 2) as drop_off_rate
FROM funnel_events
UNION ALL
SELECT 
    'Checkout Start' as stage,
    SUM(started_checkout) as sessions,
    ROUND(SUM(started_checkout) * 100.0 / NULLIF(SUM(viewed_product), 0), 2) as percentage,
    ROUND(100.0 - (SUM(started_checkout) * 100.0 / NULLIF(SUM(added_to_cart), 0)), 2) as drop_off_rate
FROM funnel_events
UNION ALL
SELECT 
    'Purchase' as stage,
    SUM(completed_purchase) as sessions,
    ROUND(SUM(completed_purchase) * 100.0 / NULLIF(SUM(viewed_product), 0), 2) as percentage,
    ROUND(100.0 - (SUM(completed_purchase) * 100.0 / NULLIF(SUM(started_checkout), 0)), 2) as drop_off_rate
FROM funnel_events;

-- Query 6: Top Referrer Sources
-- Identifies which referrer sources drive the most traffic
SELECT 
    referrer,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as sessions,
    COUNT(*) as total_events,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
    ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0 / 
        COUNT(DISTINCT session_id), 
        2
    ) as conversion_rate
FROM transformed
WHERE referrer IS NOT NULL
  AND referrer != ''
GROUP BY referrer
ORDER BY unique_users DESC
LIMIT 20;

-- Query 7: Device Type Analysis
-- Compares user behavior across different device types
SELECT 
    device_type,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as sessions,
    COUNT(*) as total_events,
    ROUND(AVG(event_sequence), 2) as avg_events_per_session,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
    ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT session_id), 0), 
        2
    ) as session_conversion_rate
FROM transformed
WHERE device_type IS NOT NULL
GROUP BY device_type
ORDER BY unique_users DESC;

-- Query 8: Revenue Analysis
-- Calculates revenue metrics from purchase events
SELECT 
    year,
    month,
    day,
    CONCAT(year, '-', month, '-', day) as date,
    COUNT(DISTINCT user_id) as purchasing_users,
    COUNT(*) as total_purchases,
    SUM(price * quantity) as total_revenue,
    ROUND(AVG(price * quantity), 2) as avg_order_value,
    ROUND(SUM(price * quantity) / COUNT(DISTINCT user_id), 2) as revenue_per_user
FROM transformed
WHERE event_type = 'purchase'
  AND price IS NOT NULL
  AND quantity IS NOT NULL
GROUP BY year, month, day
ORDER BY year DESC, month DESC, day DESC
LIMIT 30;

-- Query 9: Session Duration Analysis
-- Analyzes average session duration
WITH session_times AS (
    SELECT 
        session_id,
        MIN(timestamp) as session_start,
        MAX(timestamp) as session_end,
        COUNT(*) as event_count,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as has_purchase
    FROM transformed
    GROUP BY session_id
)
SELECT 
    CASE 
        WHEN has_purchase = 1 THEN 'Converted'
        ELSE 'Not Converted'
    END as conversion_status,
    COUNT(*) as session_count,
    ROUND(AVG(event_count), 2) as avg_events,
    ROUND(AVG(date_diff('second', 
        date_parse(session_start, '%Y-%m-%dT%H:%i:%s.%fZ'),
        date_parse(session_end, '%Y-%m-%dT%H:%i:%s.%fZ')
    )), 2) as avg_duration_seconds
FROM session_times
WHERE session_start != session_end
GROUP BY has_purchase
ORDER BY conversion_status;

-- Query 10: Category Performance
-- Analyzes performance by product category
SELECT 
    product_category,
    COUNT(DISTINCT product_id) as unique_products,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END) as views,
    SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) as cart_adds,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
    SUM(CASE WHEN event_type = 'purchase' THEN price * quantity ELSE 0 END) as revenue,
    ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END), 0), 
        2
    ) as conversion_rate
FROM transformed
WHERE product_category IS NOT NULL
GROUP BY product_category
ORDER BY revenue DESC;

-- Query 11: New vs Returning User Behavior
-- Compares behavior between first-time and returning users
WITH user_first_event AS (
    SELECT 
        user_id,
        MIN(timestamp) as first_event_time
    FROM transformed
    GROUP BY user_id
),
user_classification AS (
    SELECT 
        t.*,
        CASE 
            WHEN t.timestamp = uf.first_event_time THEN 'New User'
            ELSE 'Returning User'
        END as user_type
    FROM transformed t
    JOIN user_first_event uf ON t.user_id = uf.user_id
)
SELECT 
    user_type,
    COUNT(DISTINCT user_id) as users,
    COUNT(*) as total_events,
    ROUND(AVG(event_sequence), 2) as avg_events_per_session,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
    ROUND(
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0 / 
        COUNT(DISTINCT session_id), 
        2
    ) as conversion_rate
FROM user_classification
GROUP BY user_type;

-- Query 12: Real-time Event Monitoring
-- Shows latest events (useful for debugging/monitoring)
SELECT 
    timestamp,
    event_type,
    user_id,
    session_id,
    product_id,
    product_name,
    price,
    device_type,
    page_url
FROM transformed
WHERE year = CAST(year(current_date) AS VARCHAR)
  AND month = LPAD(CAST(month(current_date) AS VARCHAR), 2, '0')
  AND day = LPAD(CAST(day(current_date) AS VARCHAR), 2, '0')
ORDER BY timestamp DESC
LIMIT 100;

-- ============================================================================
-- Maintenance Queries
-- ============================================================================

-- Repair table partitions (run after new data is added)
MSCK REPAIR TABLE transformed;

-- Show all partitions
SHOW PARTITIONS transformed;

-- Get table statistics
ANALYZE TABLE transformed COMPUTE STATISTICS;

-- Check data quality
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT event_id) as unique_events,
    COUNT(*) - COUNT(DISTINCT event_id) as duplicate_events,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) as missing_product_id,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) as missing_price
FROM transformed;

