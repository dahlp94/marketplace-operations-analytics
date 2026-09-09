-- Independent checks against the certified analytics layer.

-- Delivery population and rate.
WITH source AS (
    SELECT
        COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
        ) AS eligible,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  > order_estimated_delivery_date::date
        ) AS late
    FROM analytics.fact_orders
)
SELECT
    s.delivered = m.delivered_orders AS delivered_matches,
    s.eligible = m.delivery_performance_eligible AS eligible_matches,
    s.late = m.late_count AS late_matches,
    ROUND(
        1 - s.late::NUMERIC / NULLIF(s.eligible, 0),
        6
    ) = ROUND(m.on_time_delivery_rate, 6) AS on_time_rate_matches
FROM source s
CROSS JOIN metrics.kpi_marketplace m;


-- Duration examples.
SELECT
    f.order_id,
    ROUND(
        EXTRACT(EPOCH FROM (
            f.order_delivered_customer_date - f.order_purchase_timestamp
        )) / 86400.0,
        6
    ) = ROUND(k.purchase_to_delivery_days::NUMERIC, 6)
        AS purchase_to_delivery_matches,
    ROUND(
        EXTRACT(EPOCH FROM (
            f.order_delivered_carrier_date - f.order_approved_at
        )) / 86400.0,
        6
    ) = ROUND(k.seller_handling_days::NUMERIC, 6)
        AS seller_handling_matches,
    ROUND(
        EXTRACT(EPOCH FROM (
            f.order_delivered_customer_date - f.order_delivered_carrier_date
        )) / 86400.0,
        6
    ) = ROUND(k.carrier_transit_days::NUMERIC, 6)
        AS carrier_transit_matches,
    (
        f.order_delivered_customer_date::date
        - f.order_estimated_delivery_date::date
    ) = k.delivery_delay_days AS delay_matches
FROM analytics.fact_orders f
JOIN metrics.kpi_orders k USING (order_id)
WHERE f.order_id IN (
    '00010242fe8c5a6d1ba2dd792cb16214',
    '00018f77f2f0320c557190d7a144bdd3',
    '000229ec398224ef6ca0657da4fc703e'
)
ORDER BY f.order_id;


-- Seller counts and GMV for known multi-seller examples.
WITH source AS (
    SELECT
        i.seller_id,
        COUNT(DISTINCT i.order_id) FILTER (
            WHERE o.order_status = 'delivered'
              AND o.order_delivered_customer_date IS NOT NULL
              AND o.order_estimated_delivery_date IS NOT NULL
        ) AS eligible_orders,
        COUNT(DISTINCT i.order_id) FILTER (
            WHERE o.order_status = 'delivered'
              AND o.order_delivered_customer_date IS NOT NULL
              AND o.order_estimated_delivery_date IS NOT NULL
              AND o.order_delivered_customer_date::date
                  > o.order_estimated_delivery_date::date
        ) AS late_orders,
        ROUND(SUM(i.price), 2) AS gmv
    FROM analytics.fact_order_items i
    JOIN analytics.fact_orders o USING (order_id)
    WHERE i.seller_id IN (
        '7299e27ed73d2ad986de7f7c77d919fa',
        'fa40cc5b934574b62717c68f3d678b6d'
    )
    GROUP BY i.seller_id
)
SELECT
    s.seller_id,
    s.eligible_orders = k.delivery_eligible_seller_orders
        AS eligible_matches,
    s.late_orders = k.late_seller_orders AS late_matches,
    s.gmv = ROUND(k.seller_gmv, 2) AS gmv_matches
FROM source s
JOIN metrics.kpi_sellers k USING (seller_id)
ORDER BY s.seller_id;


-- Review metrics and GMV.
WITH source AS (
    SELECT
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND n_usable_review_rows > 0
        )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE order_status = 'delivered'), 0)
            AS review_coverage,
        COUNT(*) FILTER (
            WHERE n_usable_review_rows > 0
              AND order_review_score <= 2
        )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE n_usable_review_rows > 0), 0)
            AS negative_review_rate,
        ROUND(SUM(merchandise_value), 2) AS gmv
    FROM analytics.fact_orders
)
SELECT
    ROUND(s.review_coverage, 6) = ROUND(m.review_coverage, 6)
        AS review_coverage_matches,
    ROUND(s.negative_review_rate, 6) = ROUND(m.negative_review_rate, 6)
        AS negative_rate_matches,
    s.gmv = m.gmv AS gmv_matches
FROM source s
CROSS JOIN metrics.kpi_marketplace m;


-- Repeat-order sequence for one known repeat customer.
WITH source AS (
    SELECT
        o.order_id,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_sequence
    FROM analytics.fact_orders o
    JOIN analytics.dim_customer c USING (customer_id)
    WHERE c.customer_unique_id = '004288347e5e88a27ded2bb23747066c'
)
SELECT
    s.order_id,
    s.order_sequence = k.customer_order_sequence AS sequence_matches,
    (s.order_sequence > 1) = k.is_repeat_order AS repeat_flag_matches
FROM source s
JOIN metrics.kpi_orders k USING (order_id)
ORDER BY s.order_sequence;
