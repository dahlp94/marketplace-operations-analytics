-- Check whether non-null timestamps follow a plausible lifecycle order.

-- Order timestamp violations.
SELECT
    COUNT(*) AS orders,
    COUNT(*) FILTER (
        WHERE order_approved_at IS NOT NULL
          AND order_approved_at < order_purchase_timestamp
    ) AS approved_before_purchase,
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NOT NULL
          AND order_approved_at IS NOT NULL
          AND order_delivered_carrier_date < order_approved_at
    ) AS carrier_before_approval,
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NOT NULL
          AND order_delivered_carrier_date < order_purchase_timestamp
    ) AS carrier_before_purchase,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date < order_delivered_carrier_date
    ) AS customer_before_carrier,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_delivered_customer_date < order_purchase_timestamp
    ) AS customer_before_purchase,
    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date < order_purchase_timestamp::date
    ) AS estimated_before_purchase_date
FROM raw.orders;

-- Same delivery-clock checks on delivered orders only.
SELECT
    COUNT(*) AS delivered_orders,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_delivered_customer_date < order_purchase_timestamp
    ) AS customer_before_purchase,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date < order_delivered_carrier_date
    ) AS customer_before_carrier
FROM raw.orders
WHERE order_status = 'delivered';

-- Review timestamp checks.
SELECT
    COUNT(*) AS review_rows,
    COUNT(*) FILTER (
        WHERE review_answer_timestamp < review_creation_date
    ) AS answer_before_creation,
    COUNT(*) FILTER (
        WHERE review_creation_date < o.order_purchase_timestamp
    ) AS created_before_purchase,
    COUNT(*) FILTER (
        WHERE o.order_status = 'delivered'
          AND o.order_delivered_customer_date IS NOT NULL
          AND review_creation_date < o.order_delivered_customer_date
    ) AS delivered_review_before_delivery
FROM raw.order_reviews r
JOIN raw.orders o
    ON o.order_id = r.order_id;

-- Shipping limit before the order was purchased.
SELECT
    COUNT(*) AS item_rows,
    COUNT(*) FILTER (
        WHERE i.shipping_limit_date < o.order_purchase_timestamp
    ) AS shipping_limit_before_purchase
FROM raw.order_items i
JOIN raw.orders o
    ON o.order_id = i.order_id;
