-- Inspect historical coverage and boundary periods.

-- Overall purchase-date range.
SELECT
    MIN(order_purchase_timestamp) AS first_purchase,
    MAX(order_purchase_timestamp) AS last_purchase
FROM raw.orders;

-- Monthly order volume and child-record coverage.
WITH items AS (
    SELECT DISTINCT order_id
    FROM raw.order_items
),
payments AS (
    SELECT DISTINCT order_id
    FROM raw.order_payments
),
reviews AS (
    SELECT DISTINCT order_id
    FROM raw.order_reviews
)
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
    COUNT(*) AS orders,
    COUNT(*) FILTER (WHERE o.order_status = 'delivered') AS delivered_orders,
    COUNT(*) FILTER (WHERE i.order_id IS NOT NULL) AS orders_with_items,
    COUNT(*) FILTER (WHERE p.order_id IS NOT NULL) AS orders_with_payments,
    COUNT(*) FILTER (WHERE r.order_id IS NOT NULL) AS orders_with_reviews
FROM raw.orders o
LEFT JOIN items i ON i.order_id = o.order_id
LEFT JOIN payments p ON p.order_id = o.order_id
LEFT JOIN reviews r ON r.order_id = o.order_id
GROUP BY 1
ORDER BY 1;

-- First and last observed purchase date within each month.
SELECT
    DATE_TRUNC('month', order_purchase_timestamp)::date AS purchase_month,
    COUNT(*) AS orders,
    MIN(order_purchase_timestamp)::date AS first_order_date,
    MAX(order_purchase_timestamp)::date AS last_order_date
FROM raw.orders
GROUP BY 1
ORDER BY 1;
