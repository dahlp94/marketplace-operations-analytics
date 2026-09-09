-- Canonical analytical populations.
-- Read-only. Uses only certified analytics.* tables.

WITH orders AS (
    SELECT
        *,
        order_status = 'delivered' AS is_delivered,
        order_status = 'delivered'
            AND order_delivered_customer_date IS NOT NULL
            AND order_estimated_delivery_date IS NOT NULL AS delivery_eligible,
        n_usable_review_rows > 0 AS has_usable_review
    FROM analytics.fact_orders
)

-- 1. Core populations.
SELECT
    COUNT(*) AS all_orders,
    COUNT(*) FILTER (WHERE is_delivered) AS delivered_orders,
    COUNT(*) FILTER (WHERE delivery_eligible) AS delivery_performance_eligible,
    COUNT(*) FILTER (WHERE eligible_purchase_to_delivery) AS purchase_to_delivery_eligible,
    COUNT(*) FILTER (WHERE eligible_seller_handling) AS seller_handling_eligible,
    COUNT(*) FILTER (WHERE eligible_carrier_transit) AS carrier_transit_eligible,
    COUNT(*) FILTER (WHERE has_usable_review) AS reviewed_orders,
    COUNT(*) FILTER (WHERE is_delivered AND has_usable_review) AS reviewed_delivered_orders,
    COUNT(*) FILTER (
        WHERE purchase_date >= DATE '2017-02-01'
          AND purchase_date < DATE '2018-09-01'
    ) AS comparable_trend_window_orders
FROM orders;

-- 2. Main exclusion counts.
WITH orders AS (
    SELECT
        *,
        order_status = 'delivered' AS is_delivered,
        order_status = 'delivered'
            AND order_delivered_customer_date IS NOT NULL
            AND order_estimated_delivery_date IS NOT NULL AS delivery_eligible
    FROM analytics.fact_orders
)
SELECT
    COUNT(*) FILTER (WHERE is_delivered AND order_delivered_customer_date IS NULL)
        AS delivered_missing_actual_delivery,
    COUNT(*) FILTER (WHERE is_delivered AND order_estimated_delivery_date IS NULL)
        AS delivered_missing_estimated_delivery,
    COUNT(*) FILTER (WHERE NOT is_delivered AND order_delivered_customer_date IS NOT NULL)
        AS non_delivered_with_actual_delivery,
    COUNT(*) FILTER (WHERE is_delivered AND NOT delivery_eligible)
        AS delivered_not_delivery_eligible,
    COUNT(*) FILTER (WHERE is_delivered AND NOT eligible_purchase_to_delivery)
        AS delivered_not_purchase_to_delivery_eligible,
    COUNT(*) FILTER (WHERE is_delivered AND NOT eligible_seller_handling)
        AS delivered_not_seller_handling_eligible,
    COUNT(*) FILTER (WHERE is_delivered AND NOT eligible_carrier_transit)
        AS delivered_not_carrier_transit_eligible,
    COUNT(*) FILTER (WHERE n_review_rows > 0 AND n_usable_review_rows = 0)
        AS review_present_but_unusable,
    COUNT(*) FILTER (WHERE n_review_rows = 0) AS no_review_rows
FROM orders;

-- 3. Timestamp shape and duration-quality exclusions.
SELECT
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NOT NULL
          AND order_estimated_delivery_date IS NOT NULL
    ) AS delivery_eligible_orders,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_estimated_delivery_date::time = TIME '00:00:00'
    ) AS estimated_at_midnight,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_approved_at IS NULL
    ) AS delivered_missing_approval,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_carrier_date IS NULL
    ) AS delivered_missing_carrier,
    COUNT(*) FILTER (WHERE order_status = 'delivered' AND carrier_before_approval)
        AS carrier_before_approval,
    COUNT(*) FILTER (WHERE order_status = 'delivered' AND carrier_before_purchase)
        AS carrier_before_purchase,
    COUNT(*) FILTER (WHERE order_status = 'delivered' AND customer_delivery_before_carrier)
        AS customer_delivery_before_carrier
FROM analytics.fact_orders;
