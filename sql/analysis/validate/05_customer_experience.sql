-- Validate customer-experience outputs against certified KPI fields.

\echo '===== review coverage ====='
SELECT
    c.reviewed_orders = m.reviewed_orders AS reviewed_match,
    c.negative_review_orders = m.negative_review_count AS negative_match,
    d.orders = m.delivered_orders AS delivered_match,
    d.reviewed_orders = m.reviewed_delivered_orders AS delivered_reviewed_match
FROM analysis.review_coverage c
JOIN analysis.review_coverage d
  ON d.population = 'delivered_orders'
CROSS JOIN metrics.kpi_marketplace m
WHERE c.population = 'all_orders';


\echo '===== delay-band reconciliation ====='
SELECT
    SUM(d.eligible_orders) AS delay_eligible,
    SUM(d.reviewed_orders) AS delay_reviewed,
    MAX(c.orders) AS certified_eligible,
    MAX(c.reviewed_orders) AS certified_reviewed
FROM analysis.delay_band_reviews d
CROSS JOIN analysis.review_coverage c
WHERE c.population = 'delivery_performance_eligible';

\echo '===== review null logic ====='
SELECT COUNT(*) AS bad_rows
FROM metrics.kpi_orders
WHERE NOT has_usable_review
  AND is_negative_review IS NOT NULL;


\echo '===== category GMV reconciliation ====='
SELECT
    ROUND(SUM(gmv), 2) AS segment_gmv,
    (
        SELECT ROUND(SUM(gmv), 2)
        FROM metrics.kpi_orders
        WHERE is_delivery_performance_eligible
    ) AS certified_gmv
FROM analysis.segment_review_performance
WHERE segment_type = 'product_category';


\echo '===== order spot checks ====='
SELECT
    o.order_id,
    o.delivery_class,
    o.delivery_delay_days
        = (f.order_delivered_customer_date::date
           - f.order_estimated_delivery_date::date) AS delay_matches,
    o.order_review_score IS NOT DISTINCT FROM f.order_review_score
        AS review_score_matches,
    o.is_negative_review
FROM metrics.kpi_orders o
JOIN analytics.fact_orders f USING (order_id)
WHERE o.order_id IN (
    '0017afd5076e074a48f1f1a4c7bac9c5',
    '00010242fe8c5a6d1ba2dd792cb16214',
    '00143d0f86d6fbd9f9b38ab440ac16f5',
    '0005a1a1728c9d785b8e2b08b904576c'
)
ORDER BY o.order_id;
