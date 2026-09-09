-- Metric definition prototypes.
-- Read-only. These queries test metric contracts; they do not create KPI marts.

-- 1. Delivery classification and marketplace rates.
WITH delivery AS (
    SELECT
        order_id,
        order_delivered_customer_date::date AS actual_date,
        order_estimated_delivery_date::date AS estimated_date,
        order_delivered_customer_date::date - order_estimated_delivery_date::date
            AS delivery_delay_days,
        CASE
            WHEN order_delivered_customer_date::date < order_estimated_delivery_date::date THEN 'early'
            WHEN order_delivered_customer_date::date = order_estimated_delivery_date::date THEN 'on_time'
            ELSE 'late'
        END AS delivery_class
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    COUNT(*) AS eligible_orders,
    COUNT(*) FILTER (WHERE delivery_class = 'early') AS early_orders,
    COUNT(*) FILTER (WHERE delivery_class = 'on_time') AS on_time_orders,
    COUNT(*) FILTER (WHERE delivery_class = 'late') AS late_orders,
    ROUND(
        COUNT(*) FILTER (WHERE delivery_class <> 'late')::NUMERIC / COUNT(*),
        6
    ) AS on_time_delivery_rate,
    ROUND(
        COUNT(*) FILTER (WHERE delivery_class = 'late')::NUMERIC / COUNT(*),
        6
    ) AS late_delivery_rate,
    ROUND(AVG(delivery_delay_days), 4) AS avg_delivery_delay_days,
    ROUND(AVG(GREATEST(delivery_delay_days, 0)), 4) AS avg_late_days
FROM delivery;

-- 2. Fulfillment durations in elapsed days.
SELECT
    COUNT(*) FILTER (WHERE eligible_purchase_to_delivery) AS purchase_to_delivery_n,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0
    ) FILTER (WHERE eligible_purchase_to_delivery), 4) AS avg_purchase_to_delivery_days,

    COUNT(*) FILTER (WHERE eligible_seller_handling) AS seller_handling_n,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 86400.0
    ) FILTER (WHERE eligible_seller_handling), 4) AS avg_seller_handling_days,

    COUNT(*) FILTER (WHERE eligible_carrier_transit) AS carrier_transit_n,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 86400.0
    ) FILTER (WHERE eligible_carrier_transit), 4) AS avg_carrier_transit_days,

    ROUND(AVG(
        order_estimated_delivery_date::date - order_purchase_timestamp::date
    ) FILTER (
        WHERE order_status = 'delivered'
          AND order_estimated_delivery_date IS NOT NULL
    ), 4) AS avg_promised_window_days
FROM analytics.fact_orders;

-- 3. Commercial measures. Keep these concepts separate.
SELECT
    ROUND(SUM(merchandise_value), 2) AS merchandise_gmv,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(SUM(item_side_value), 2) AS item_side_value,
    ROUND(SUM(collected_payment), 2) AS collected_payment
FROM analytics.fact_orders;

-- 4. Seller-order attribution.
-- A late order is attributed once to each seller participating in that order.
WITH delivery AS (
    SELECT
        order_id,
        merchandise_value,
        order_delivered_customer_date::date > order_estimated_delivery_date::date AS is_late
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
seller_orders AS (
    SELECT
        i.seller_id,
        i.order_id,
        SUM(i.price) AS seller_gmv
    FROM analytics.fact_order_items i
    JOIN delivery d USING (order_id)
    GROUP BY i.seller_id, i.order_id
)
SELECT
    COUNT(DISTINCT d.order_id) AS eligible_orders,
    COUNT(DISTINCT d.order_id) FILTER (WHERE d.is_late) AS late_orders,
    COUNT(*) AS eligible_seller_orders,
    COUNT(*) FILTER (WHERE d.is_late) AS late_seller_orders,
    ROUND(SUM(s.seller_gmv), 2) AS seller_gmv_sum,
    ROUND(SUM(s.seller_gmv) FILTER (WHERE d.is_late), 2) AS late_seller_gmv_sum
FROM seller_orders s
JOIN delivery d USING (order_id);

-- 5. Customer-experience metrics.
SELECT
    COUNT(*) FILTER (WHERE n_usable_review_rows > 0) AS reviewed_orders,
    ROUND(
        COUNT(*) FILTER (
            WHERE order_status = 'delivered' AND n_usable_review_rows > 0
        )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE order_status = 'delivered'), 0),
        6
    ) AS review_coverage_delivered,
    ROUND(AVG(order_review_score) FILTER (WHERE n_usable_review_rows > 0), 4)
        AS avg_review_score,
    COUNT(*) FILTER (
        WHERE n_usable_review_rows > 0 AND order_review_score <= 2
    ) AS negative_review_orders,
    ROUND(
        COUNT(*) FILTER (
            WHERE n_usable_review_rows > 0 AND order_review_score <= 2
        )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE n_usable_review_rows > 0), 0),
        6
    ) AS negative_review_rate,
    COUNT(*) FILTER (WHERE n_review_rows > 0 AND n_usable_review_rows = 0)
        AS unusable_review_only_orders
FROM analytics.fact_orders;

-- 6. Review-score bands.
SELECT
    CASE
        WHEN order_review_score <= 2 THEN 'negative'
        WHEN order_review_score < 4 THEN 'neutral'
        ELSE 'positive'
    END AS review_band,
    COUNT(*) AS n_orders
FROM analytics.fact_orders
WHERE n_usable_review_rows > 0
GROUP BY 1
ORDER BY 1;

-- 7. Repeat-customer sequence using persistent customer identity.
WITH sequenced AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM analytics.fact_orders o
    JOIN analytics.dim_customer c
        ON c.customer_id = o.customer_id
)
SELECT
    COUNT(*) AS orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    COUNT(*) FILTER (WHERE order_sequence = 1) AS first_orders,
    COUNT(*) FILTER (WHERE order_sequence > 1) AS repeat_orders,
    COUNT(DISTINCT customer_unique_id) FILTER (WHERE order_sequence > 1)
        AS repeat_customers
FROM sequenced;
