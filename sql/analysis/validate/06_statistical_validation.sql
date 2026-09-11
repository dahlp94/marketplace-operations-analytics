-- Validate statistical-validation inputs against certified sources.

\echo '===== inference population ====='
SELECT
    COUNT(*) AS delivered_in_extract,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible) AS eligible_in_extract,
    (SELECT COUNT(*) FILTER (WHERE is_delivered) FROM metrics.kpi_orders)
        AS certified_delivered,
    (SELECT COUNT(*) FILTER (WHERE is_delivery_performance_eligible)
     FROM metrics.kpi_orders) AS certified_eligible
FROM analysis.inference_orders;


\echo '===== review null logic ====='
SELECT COUNT(*) AS bad_rows
FROM analysis.inference_orders
WHERE NOT has_usable_review
  AND is_negative_review IS NOT NULL;


\echo '===== rate reconciliation ====='
WITH source AS (
    SELECT
        'marketplace_late_all_eligible'::text AS population,
        late_count::integer AS numerator,
        delivery_performance_eligible::integer AS denominator
    FROM metrics.kpi_marketplace

    UNION ALL

    SELECT
        'negative_review_' || delivery_class,
        negative_review_orders,
        reviewed_orders
    FROM analysis.delivery_class_review_rates
    WHERE delivery_class IN ('early', 'late')

    UNION ALL

    SELECT
        'negative_review_' || delay_band,
        negative_review_orders,
        reviewed_orders
    FROM analysis.delay_band_reviews
    WHERE delay_band LIKE 'late_%'

    UNION ALL

    SELECT
        'watchlist_seller_order_late',
        SUM(late_seller_orders)::integer,
        SUM(delivery_eligible_seller_orders)::integer
    FROM analysis.seller_watchlist
)
SELECT
    s.population,
    i.numerator = s.numerator AS numerator_match,
    i.denominator = s.denominator AS denominator_match
FROM source s
JOIN analysis.inference_rate_counts i USING (population)
ORDER BY s.population;
