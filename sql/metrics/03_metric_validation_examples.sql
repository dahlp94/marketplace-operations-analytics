-- Validation examples for metric definitions.
-- Read-only. Keep only examples that prove an important edge case.

-- 1. Known lineage and edge cases.
SELECT
    CASE o.order_id
        WHEN '00143d0f86d6fbd9f9b38ab440ac16f5' THEN 'multi_item'
        WHEN '009ac365164f8e06f59d18a08045f6c4' THEN 'multi_payment'
        WHEN '002f98c0f7efd42638ed6100ca699b42' THEN 'multi_seller'
        WHEN 'bfbd0f9bdef84302105ad712db648a6c' THEN 'no_payment'
        WHEN 'ce6d150fb29ada17d2082f4847107665' THEN 'monetary_mismatch'
    END AS case_name,
    o.order_id,
    o.order_status,
    o.n_items,
    o.n_sellers,
    o.n_payment_rows,
    o.merchandise_value,
    o.collected_payment
FROM analytics.fact_orders o
WHERE o.order_id IN (
    '00143d0f86d6fbd9f9b38ab440ac16f5',
    '009ac365164f8e06f59d18a08045f6c4',
    '002f98c0f7efd42638ed6100ca699b42',
    'bfbd0f9bdef84302105ad712db648a6c',
    'ce6d150fb29ada17d2082f4847107665'
)
ORDER BY case_name;

-- 2. Multi-seller order: item value stays with the actual seller.
SELECT
    i.order_id,
    i.order_item_id,
    i.seller_id,
    i.price,
    i.freight_value
FROM analytics.fact_order_items i
WHERE i.order_id = '002f98c0f7efd42638ed6100ca699b42'
ORDER BY i.order_item_id;

-- 3. One early, one on-time, and one late order.
WITH classified AS (
    SELECT
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date
            AS delivery_delay_days,
        CASE
            WHEN o.order_delivered_customer_date::date < o.order_estimated_delivery_date::date THEN 'early'
            WHEN o.order_delivered_customer_date::date = o.order_estimated_delivery_date::date THEN 'on_time'
            ELSE 'late'
        END AS delivery_class
    FROM analytics.fact_orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),
examples AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY delivery_class ORDER BY order_id) AS rn
    FROM classified
)
SELECT
    delivery_class,
    order_id,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    delivery_delay_days
FROM examples
WHERE rn = 1
ORDER BY delivery_class;

-- 4. Delivered orders excluded because the actual delivery timestamp is missing.
SELECT
    order_id,
    order_status,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    eligible_on_time_delivery,
    has_status_timestamp_conflict
FROM analytics.fact_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL
ORDER BY order_id
LIMIT 5;

-- 5. A few valid fulfillment-duration examples.
SELECT
    order_id,
    ROUND(EXTRACT(EPOCH FROM (
        order_delivered_customer_date - order_purchase_timestamp
    )) / 86400.0, 4) AS purchase_to_delivery_days,
    ROUND(EXTRACT(EPOCH FROM (
        order_delivered_carrier_date - order_approved_at
    )) / 86400.0, 4) AS seller_handling_days,
    ROUND(EXTRACT(EPOCH FROM (
        order_delivered_customer_date - order_delivered_carrier_date
    )) / 86400.0, 4) AS carrier_transit_days,
    order_estimated_delivery_date::date - order_purchase_timestamp::date
        AS promised_window_days
FROM analytics.fact_orders
WHERE eligible_purchase_to_delivery
  AND eligible_seller_handling
  AND eligible_carrier_transit
ORDER BY order_id
LIMIT 3;

-- 6. One example for each important review state.
WITH review_cases AS (
    SELECT
        order_id,
        n_review_rows,
        n_usable_review_rows,
        order_review_score,
        CASE
            WHEN n_review_rows = 0 THEN 'no_review'
            WHEN n_review_rows > 0 AND n_usable_review_rows = 0 THEN 'unusable_review'
            WHEN n_usable_review_rows > 0 AND order_review_score <= 2 THEN 'negative_review'
            WHEN n_usable_review_rows > 0 AND order_review_score >= 4 THEN 'positive_review'
        END AS case_name
    FROM analytics.fact_orders
),
examples AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY case_name ORDER BY order_id) AS rn
    FROM review_cases
    WHERE case_name IS NOT NULL
)
SELECT
    case_name,
    order_id,
    n_review_rows,
    n_usable_review_rows,
    order_review_score
FROM examples
WHERE rn = 1
ORDER BY case_name;

-- 7. First and repeat orders for one repeat customer.
WITH sequenced AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM analytics.fact_orders o
    JOIN analytics.dim_customer c
        ON c.customer_id = o.customer_id
),
example_customer AS (
    SELECT customer_unique_id
    FROM sequenced
    GROUP BY customer_unique_id
    HAVING COUNT(*) >= 2
    ORDER BY customer_unique_id
    LIMIT 1
)
SELECT
    s.customer_unique_id,
    s.order_id,
    s.order_purchase_timestamp,
    s.order_sequence,
    s.order_sequence > 1 AS is_repeat_order
FROM sequenced s
JOIN example_customer e USING (customer_unique_id)
ORDER BY s.order_sequence;

-- 8. Low-volume seller edge case: exactly one eligible seller-order.
WITH seller_orders AS (
    SELECT DISTINCT
        i.seller_id,
        i.order_id,
        o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date AS is_late
    FROM analytics.fact_order_items i
    JOIN analytics.fact_orders o USING (order_id)
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),
seller_summary AS (
    SELECT
        seller_id,
        COUNT(*) AS eligible_orders,
        COUNT(*) FILTER (WHERE is_late) AS late_orders
    FROM seller_orders
    GROUP BY seller_id
)
SELECT
    seller_id,
    eligible_orders,
    late_orders,
    ROUND(late_orders::NUMERIC / eligible_orders, 6) AS late_rate
FROM seller_summary
WHERE eligible_orders = 1
ORDER BY late_orders DESC, seller_id
LIMIT 3;

-- 9. Same calendar date can still look late if raw timestamps are compared.
SELECT
    order_id,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    order_delivered_customer_date::date - order_estimated_delivery_date::date
        AS delivery_delay_days,
    order_delivered_customer_date > order_estimated_delivery_date AS timestamp_would_be_late
FROM analytics.fact_orders
WHERE order_id = '0005a1a1728c9d785b8e2b08b904576c';

-- 10. Retained quality-flag example.
SELECT
    order_id,
    carrier_before_approval,
    eligible_on_time_delivery,
    eligible_seller_handling,
    eligible_carrier_transit
FROM analytics.fact_orders
WHERE order_status = 'delivered'
  AND carrier_before_approval
ORDER BY order_id
LIMIT 2;
