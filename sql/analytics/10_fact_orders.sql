-- One row per order.
-- Child tables are aggregated independently before joining to avoid fan-out.

DROP TABLE IF EXISTS analytics.fact_orders;

CREATE TABLE analytics.fact_orders AS
WITH item_rollup AS (
    SELECT
        order_id,
        COUNT(*)::INTEGER AS n_items,
        COUNT(DISTINCT seller_id)::INTEGER AS n_sellers,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value,
        SUM(item_side_value) AS item_side_value
    FROM stg.order_items
    GROUP BY order_id
),
payment_rollup AS (
    SELECT
        order_id,
        COUNT(*)::INTEGER AS n_payment_rows,
        SUM(payment_value) AS collected_payment
    FROM stg.order_payments
    GROUP BY order_id
),
review_rollup AS (
    SELECT
        order_id,
        COUNT(*)::INTEGER AS n_review_rows,
        COUNT(*) FILTER (
            WHERE NOT review_id_reused
        )::INTEGER AS n_usable_review_rows,
        AVG(review_score) FILTER (
            WHERE NOT review_id_reused
        ) AS order_review_score
    FROM stg.order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp::date AS purchase_date,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    COALESCE(i.n_items, 0) AS n_items,
    COALESCE(i.n_sellers, 0) AS n_sellers,
    i.merchandise_value,
    i.freight_value,
    i.item_side_value,

    COALESCE(p.n_payment_rows, 0) AS n_payment_rows,
    p.collected_payment,

    CASE
        WHEN i.item_side_value IS NULL
          OR p.collected_payment IS NULL
        THEN NULL
        ELSE p.collected_payment - i.item_side_value
    END AS payment_item_gap,

    CASE
        WHEN i.item_side_value IS NULL
          OR p.collected_payment IS NULL
        THEN NULL
        ELSE ABS(p.collected_payment - i.item_side_value) > 0.01
    END AS monetary_diff_gt_tolerance,

    COALESCE(r.n_review_rows, 0) AS n_review_rows,
    COALESCE(r.n_usable_review_rows, 0) AS n_usable_review_rows,
    r.order_review_score,

    o.carrier_before_approval,
    o.carrier_before_purchase,
    o.customer_delivery_before_carrier,
    o.has_status_timestamp_conflict,

    o.eligible_on_time_delivery,
    o.eligible_purchase_to_delivery,
    o.eligible_seller_handling,
    o.eligible_carrier_transit

FROM stg.orders o
LEFT JOIN item_rollup i
    ON i.order_id = o.order_id
LEFT JOIN payment_rollup p
    ON p.order_id = o.order_id
LEFT JOIN review_rollup r
    ON r.order_id = o.order_id;
