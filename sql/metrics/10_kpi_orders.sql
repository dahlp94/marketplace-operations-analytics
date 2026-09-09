-- Order-level KPI base.
-- Grain: one row per order_id.
-- Ineligible orders remain in the table; metric fields are NULL when not applicable.

DROP TABLE IF EXISTS metrics.kpi_orders;

CREATE TABLE metrics.kpi_orders AS
WITH base AS (
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        o.purchase_date,
        DATE_TRUNC('month', o.purchase_date)::date AS purchase_month,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date::date AS actual_delivery_date,
        o.order_estimated_delivery_date::date AS estimated_delivery_date,
        o.n_items,
        o.n_sellers,
        o.merchandise_value,
        o.freight_value,
        o.item_side_value,
        o.n_payment_rows,
        o.collected_payment,
        o.n_review_rows,
        o.n_usable_review_rows,
        o.order_review_score,
        o.carrier_before_approval,
        o.carrier_before_purchase,
        o.customer_delivery_before_carrier,
        o.has_status_timestamp_conflict,
        o.eligible_on_time_delivery,
        o.eligible_purchase_to_delivery,
        o.eligible_seller_handling,
        o.eligible_carrier_transit,
        (o.order_status = 'delivered') AS is_delivered,
        (
            o.order_status = 'delivered'
            AND o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL
        ) AS is_delivery_performance_eligible,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS customer_order_sequence
    FROM analytics.fact_orders o
    JOIN analytics.dim_customer c
        ON c.customer_id = o.customer_id
)
SELECT
    order_id,
    customer_id,
    customer_unique_id,
    purchase_date,
    purchase_month,
    order_status,
    n_items,
    n_sellers,
    n_payment_rows,

    is_delivered,
    is_delivery_performance_eligible,
    eligible_purchase_to_delivery AS is_purchase_to_delivery_eligible,
    eligible_seller_handling AS is_seller_handling_eligible,
    eligible_carrier_transit AS is_carrier_transit_eligible,
    purchase_date >= DATE '2017-02-01'
        AND purchase_date < DATE '2018-09-01' AS is_comparable_trend_window,
    eligible_on_time_delivery AS source_eligible_on_time_delivery,

    CASE
        WHEN order_status <> 'delivered' THEN 'not_delivered'
        WHEN actual_delivery_date IS NULL THEN 'missing_actual_delivery'
        WHEN estimated_delivery_date IS NULL THEN 'missing_estimated_delivery'
    END AS delivery_performance_exclusion_reason,

    actual_delivery_date,
    estimated_delivery_date,

    CASE
        WHEN is_delivery_performance_eligible THEN
            CASE
                WHEN actual_delivery_date < estimated_delivery_date THEN 'early'
                WHEN actual_delivery_date = estimated_delivery_date THEN 'on_time'
                ELSE 'late'
            END
    END AS delivery_class,

    CASE
        WHEN is_delivery_performance_eligible
            THEN actual_delivery_date <= estimated_delivery_date
    END AS is_on_time,

    CASE
        WHEN is_delivery_performance_eligible
            THEN actual_delivery_date > estimated_delivery_date
    END AS is_late,

    CASE
        WHEN is_delivery_performance_eligible
            THEN actual_delivery_date - estimated_delivery_date
    END AS delivery_delay_days,

    CASE
        WHEN is_delivery_performance_eligible
            THEN GREATEST(actual_delivery_date - estimated_delivery_date, 0)
    END AS late_days,

    CASE
        WHEN eligible_purchase_to_delivery THEN
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date - order_purchase_timestamp
            )) / 86400.0
    END AS purchase_to_delivery_days,

    CASE
        WHEN eligible_seller_handling THEN
            EXTRACT(EPOCH FROM (
                order_delivered_carrier_date - order_approved_at
            )) / 86400.0
    END AS seller_handling_days,

    CASE
        WHEN eligible_carrier_transit THEN
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date - order_delivered_carrier_date
            )) / 86400.0
    END AS carrier_transit_days,

    CASE
        WHEN is_delivered AND estimated_delivery_date IS NOT NULL
            THEN estimated_delivery_date - order_purchase_timestamp::date
    END AS promised_window_days,

    merchandise_value AS gmv,
    freight_value,
    item_side_value,
    collected_payment,
    CASE
        WHEN is_delivery_performance_eligible
         AND actual_delivery_date > estimated_delivery_date
            THEN merchandise_value
    END AS late_gmv,

    n_review_rows,
    n_usable_review_rows,
    n_usable_review_rows > 0 AS has_usable_review,
    n_review_rows > 0 AND n_usable_review_rows = 0 AS review_unusable_only,
    n_review_rows = 0 AS has_no_review,
    order_review_score,
    CASE
        WHEN n_usable_review_rows > 0
            THEN order_review_score <= 2
    END AS is_negative_review,
    CASE
        WHEN n_usable_review_rows > 0 AND order_review_score <= 2 THEN 'negative'
        WHEN n_usable_review_rows > 0 AND order_review_score < 4 THEN 'neutral'
        WHEN n_usable_review_rows > 0 THEN 'positive'
    END AS review_band,

    customer_order_sequence,
    customer_order_sequence > 1 AS is_repeat_order,

    carrier_before_approval,
    carrier_before_purchase,
    customer_delivery_before_carrier,
    has_status_timestamp_conflict
FROM base;
