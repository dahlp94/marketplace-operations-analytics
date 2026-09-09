-- Geography, repeat-order, and delivery-review descriptive tables.
-- Certified dimensions and metric flags are reused to avoid fan-out or redefinition.

DROP TABLE IF EXISTS analysis.customer_state_performance;
DROP TABLE IF EXISTS analysis.seller_state_performance;
DROP TABLE IF EXISTS analysis.repeat_order_performance;
DROP TABLE IF EXISTS analysis.delivery_review_mix;
DROP TABLE IF EXISTS analysis.delivery_class_review_rates;

CREATE TABLE analysis.customer_state_performance AS
SELECT
    c.state AS customer_state,
    COUNT(*)::INTEGER AS all_orders,
    COUNT(*) FILTER (
        WHERE o.is_delivery_performance_eligible
    )::INTEGER AS delivery_performance_eligible,
    COUNT(*) FILTER (WHERE o.is_late)::INTEGER AS late_count,
    COUNT(*) FILTER (WHERE o.is_late)::NUMERIC
        / NULLIF(
            COUNT(*) FILTER (WHERE o.is_delivery_performance_eligible), 0
        ) AS late_delivery_rate,
    ROUND(SUM(o.gmv), 2) AS gmv,
    ROUND(SUM(o.late_gmv), 2) AS late_gmv,
    COUNT(*) FILTER (
        WHERE o.is_delivered AND o.has_usable_review
    )::INTEGER AS reviewed_delivered_orders,
    COUNT(*) FILTER (
        WHERE o.is_delivered AND o.has_usable_review
    )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE o.is_delivered), 0)
        AS review_coverage,
    COUNT(*) FILTER (WHERE o.is_negative_review)::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE o.has_usable_review), 0)
        AS negative_review_rate,
    COUNT(*) FILTER (WHERE g.geo_unmatched)::INTEGER AS unmatched_geo_orders
FROM metrics.kpi_orders o
JOIN analytics.dim_customer c USING (customer_id)
LEFT JOIN analytics.dim_geography g
    ON g.zip_code_prefix = c.zip_code_prefix
GROUP BY c.state;


CREATE TABLE analysis.seller_state_performance AS
SELECT
    d.state AS seller_state,
    COUNT(*)::INTEGER AS seller_order_volume,
    COUNT(*) FILTER (
        WHERE s.is_delivery_performance_eligible
    )::INTEGER AS delivery_eligible_seller_orders,
    COUNT(*) FILTER (WHERE s.is_late)::INTEGER AS late_seller_orders,
    COUNT(*) FILTER (WHERE s.is_late)::NUMERIC
        / NULLIF(
            COUNT(*) FILTER (WHERE s.is_delivery_performance_eligible), 0
        ) AS seller_late_rate,
    ROUND(SUM(s.seller_gmv), 2) AS seller_gmv,
    ROUND(SUM(s.seller_late_gmv), 2) AS seller_late_gmv,
    COUNT(DISTINCT s.seller_id)::INTEGER AS n_sellers
FROM metrics.kpi_seller_orders s
JOIN analytics.dim_seller d USING (seller_id)
GROUP BY d.state;


CREATE TABLE analysis.repeat_order_performance AS
SELECT
    CASE
        WHEN customer_order_sequence = 1 THEN 'first_order'
        WHEN customer_order_sequence = 2 THEN 'second_order'
        ELSE 'third_or_later_order'
    END AS order_sequence_band,
    is_repeat_order,
    COUNT(*)::INTEGER AS all_orders,
    COUNT(*) FILTER (
        WHERE is_delivery_performance_eligible
    )::INTEGER AS delivery_performance_eligible,
    COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_count,
    COUNT(*) FILTER (WHERE is_late)::NUMERIC
        / NULLIF(
            COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0
        ) AS late_delivery_rate,
    AVG(purchase_to_delivery_days) AS avg_purchase_to_delivery_days,
    ROUND(SUM(gmv), 2) AS gmv,
    ROUND(SUM(late_gmv), 2) AS late_gmv,
    COUNT(*) FILTER (WHERE has_usable_review)::INTEGER AS reviewed_orders,
    AVG(order_review_score) AS avg_review_score,
    COUNT(*) FILTER (WHERE is_negative_review)::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate
FROM metrics.kpi_orders
GROUP BY 1, 2;


CREATE TABLE analysis.delivery_review_mix AS
WITH grouped AS (
    SELECT
        CASE
            WHEN is_delivery_performance_eligible THEN delivery_class
            ELSE 'unclassified'
        END AS delivery_class,
        CASE
            WHEN has_usable_review THEN review_band
            ELSE 'no_usable_review'
        END AS review_status,
        COUNT(*)::INTEGER AS n_orders,
        ROUND(SUM(gmv), 2) AS gmv
    FROM metrics.kpi_orders
    WHERE is_delivered
    GROUP BY 1, 2
)
SELECT
    delivery_class,
    review_status,
    n_orders,
    gmv,
    SUM(n_orders) OVER (
        PARTITION BY delivery_class
    ) AS orders_in_delivery_class,
    n_orders::NUMERIC
        / NULLIF(SUM(n_orders) OVER (PARTITION BY delivery_class), 0)
        AS pct_within_delivery_class,
    SUM(n_orders) OVER (
        PARTITION BY review_status
    ) AS orders_in_review_status,
    n_orders::NUMERIC
        / NULLIF(SUM(n_orders) OVER (PARTITION BY review_status), 0)
        AS pct_within_review_status,
    SUM(n_orders) OVER () AS delivered_orders,
    n_orders::NUMERIC / NULLIF(SUM(n_orders) OVER (), 0)
        AS pct_of_delivered
FROM grouped;


CREATE TABLE analysis.delivery_class_review_rates AS
SELECT
    delivery_class,
    COUNT(*)::INTEGER AS classified_delivered_orders,
    COUNT(*) FILTER (WHERE has_usable_review)::INTEGER AS reviewed_orders,
    COUNT(*) FILTER (
        WHERE NOT has_usable_review
    )::INTEGER AS without_usable_review,
    COUNT(*) FILTER (
        WHERE is_negative_review
    )::INTEGER AS negative_review_orders,
    COUNT(*) FILTER (WHERE is_negative_review)::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate,
    AVG(order_review_score) AS avg_review_score,
    ROUND(SUM(gmv), 2) AS gmv
FROM metrics.kpi_orders
WHERE is_delivery_performance_eligible
GROUP BY delivery_class;
