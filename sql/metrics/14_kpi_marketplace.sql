-- Marketplace KPI summaries.
-- Grains:
--   kpi_marketplace       : one row for the full extract
--   kpi_marketplace_month : one row per purchase month
--   kpi_review_bands      : one row per review band
--   kpi_delivery_review   : one row per delivery class x review status

DROP TABLE IF EXISTS metrics.kpi_marketplace;
DROP TABLE IF EXISTS metrics.kpi_marketplace_month;
DROP TABLE IF EXISTS metrics.kpi_review_bands;
DROP TABLE IF EXISTS metrics.kpi_delivery_review;

CREATE TABLE metrics.kpi_marketplace AS
SELECT
    COUNT(*) AS all_orders,
    COUNT(*) FILTER (WHERE is_delivered) AS delivered_orders,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible)
        AS delivery_performance_eligible,
    COUNT(*) FILTER (
        WHERE delivery_performance_exclusion_reason = 'not_delivered'
    ) AS excluded_not_delivered,
    COUNT(*) FILTER (
        WHERE delivery_performance_exclusion_reason = 'missing_actual_delivery'
    ) AS excluded_missing_actual_delivery,
    COUNT(*) FILTER (WHERE is_purchase_to_delivery_eligible)
        AS purchase_to_delivery_eligible,
    COUNT(*) FILTER (WHERE is_seller_handling_eligible)
        AS seller_handling_eligible,
    COUNT(*) FILTER (WHERE is_carrier_transit_eligible)
        AS carrier_transit_eligible,

    COUNT(*) FILTER (WHERE delivery_class = 'early') AS early_count,
    COUNT(*) FILTER (WHERE delivery_class = 'on_time') AS exact_on_time_count,
    COUNT(*) FILTER (WHERE is_on_time) AS on_time_count,
    COUNT(*) FILTER (WHERE is_late) AS late_count,
    COUNT(*) FILTER (WHERE is_on_time)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0)
        AS on_time_delivery_rate,
    COUNT(*) FILTER (WHERE is_late)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0)
        AS late_delivery_rate,

    AVG(delivery_delay_days) AS avg_delivery_delay_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_delay_days)
        AS median_delivery_delay_days,
    AVG(late_days) AS avg_late_days,
    AVG(purchase_to_delivery_days) AS avg_purchase_to_delivery_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY purchase_to_delivery_days)
        AS median_purchase_to_delivery_days,
    AVG(seller_handling_days) AS avg_seller_handling_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY seller_handling_days)
        AS median_seller_handling_days,
    AVG(carrier_transit_days) AS avg_carrier_transit_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY carrier_transit_days)
        AS median_carrier_transit_days,
    AVG(promised_window_days) AS avg_promised_window_days,

    ROUND(SUM(gmv), 2) AS gmv,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(SUM(item_side_value), 2) AS item_side_value,
    ROUND(SUM(collected_payment), 2) AS collected_payment,
    ROUND(SUM(late_gmv), 2) AS late_gmv,

    COUNT(*) FILTER (WHERE has_usable_review) AS reviewed_orders,
    COUNT(*) FILTER (WHERE is_delivered AND has_usable_review)
        AS reviewed_delivered_orders,
    COUNT(*) FILTER (WHERE review_unusable_only) AS review_unusable_only_orders,
    COUNT(*) FILTER (WHERE has_no_review) AS no_review_orders,
    COUNT(*) FILTER (WHERE is_delivered AND has_usable_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_delivered), 0) AS review_coverage,
    AVG(order_review_score) AS avg_review_score,
    COUNT(*) FILTER (WHERE is_negative_review) AS negative_review_count,
    COUNT(*) FILTER (WHERE is_negative_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate,

    COUNT(*) FILTER (WHERE is_repeat_order) AS repeat_orders,
    COUNT(*) FILTER (WHERE customer_order_sequence = 1) AS first_orders,
    COUNT(*) FILTER (WHERE is_comparable_trend_window)
        AS comparable_trend_window_orders
FROM metrics.kpi_orders;

CREATE TABLE metrics.kpi_marketplace_month AS
SELECT
    purchase_month,
    BOOL_OR(is_comparable_trend_window) AS is_comparable_trend_window,
    COUNT(*) AS all_orders,
    COUNT(*) FILTER (WHERE is_delivered) AS delivered_orders,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible)
        AS delivery_performance_eligible,
    COUNT(*) FILTER (
        WHERE delivery_performance_exclusion_reason = 'missing_actual_delivery'
    ) AS excluded_missing_actual_delivery,

    COUNT(*) FILTER (WHERE delivery_class = 'early') AS early_count,
    COUNT(*) FILTER (WHERE delivery_class = 'on_time') AS exact_on_time_count,
    COUNT(*) FILTER (WHERE is_on_time) AS on_time_count,
    COUNT(*) FILTER (WHERE is_late) AS late_count,
    COUNT(*) FILTER (WHERE is_on_time)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0)
        AS on_time_delivery_rate,
    COUNT(*) FILTER (WHERE is_late)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0)
        AS late_delivery_rate,

    AVG(delivery_delay_days) AS avg_delivery_delay_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_delay_days)
        AS median_delivery_delay_days,
    AVG(purchase_to_delivery_days) AS avg_purchase_to_delivery_days,
    AVG(seller_handling_days) AS avg_seller_handling_days,
    AVG(carrier_transit_days) AS avg_carrier_transit_days,
    AVG(promised_window_days) AS avg_promised_window_days,

    ROUND(SUM(gmv), 2) AS gmv,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(SUM(collected_payment), 2) AS collected_payment,
    ROUND(SUM(late_gmv), 2) AS late_gmv,

    COUNT(*) FILTER (WHERE is_delivered AND has_usable_review)
        AS reviewed_delivered_orders,
    COUNT(*) FILTER (WHERE is_delivered AND has_usable_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_delivered), 0) AS review_coverage,
    AVG(order_review_score) AS avg_review_score,
    COUNT(*) FILTER (WHERE is_negative_review) AS negative_review_count,
    COUNT(*) FILTER (WHERE is_negative_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate,
    COUNT(*) FILTER (WHERE is_repeat_order) AS repeat_orders
FROM metrics.kpi_orders
GROUP BY purchase_month;

CREATE TABLE metrics.kpi_review_bands AS
SELECT
    review_band,
    COUNT(*) AS n_orders,
    ROUND(AVG(order_review_score), 4) AS avg_review_score,
    ROUND(SUM(gmv), 2) AS gmv
FROM metrics.kpi_orders
WHERE has_usable_review
GROUP BY review_band;

CREATE TABLE metrics.kpi_delivery_review AS
SELECT
    CASE
        WHEN is_delivery_performance_eligible THEN delivery_class
        ELSE 'unclassified'
    END AS delivery_class,
    CASE
        WHEN has_usable_review THEN review_band
        ELSE 'no_usable_review'
    END AS review_status,
    COUNT(*) AS n_orders,
    ROUND(SUM(gmv), 2) AS gmv
FROM metrics.kpi_orders
WHERE is_delivered
GROUP BY 1, 2;
