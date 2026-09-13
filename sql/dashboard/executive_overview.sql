-- Executive snapshot plus customer-experience extracts.

CREATE VIEW dashboard.executive_overview AS
WITH scope_metrics AS (
    SELECT
        'full_extract'::text AS reporting_scope,
        'order'::text AS unit_grain,
        all_orders::integer AS all_orders,
        delivered_orders::integer AS delivered_orders,
        delivery_performance_eligible::integer AS delivery_performance_eligible,
        on_time_count::integer AS on_time_count,
        late_count::integer AS late_count,
        on_time_delivery_rate,
        late_delivery_rate,
        gmv,
        late_gmv,
        avg_delivery_delay_days,
        median_delivery_delay_days,
        reviewed_orders::integer AS reviewed_orders,
        negative_review_count::integer AS negative_review_count,
        negative_review_rate,
        review_coverage
    FROM metrics.kpi_marketplace

    UNION ALL

    SELECT
        'comparable_trend_window',
        'order',
        COUNT(*)::integer,
        COUNT(*) FILTER (WHERE is_delivered)::integer,
        COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::integer,
        COUNT(*) FILTER (WHERE is_on_time)::integer,
        COUNT(*) FILTER (WHERE is_late)::integer,
        COUNT(*) FILTER (WHERE is_on_time)::numeric
            / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0),
        COUNT(*) FILTER (WHERE is_late)::numeric
            / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0),
        ROUND(SUM(gmv), 2),
        ROUND(SUM(late_gmv), 2),
        AVG(delivery_delay_days),
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_delay_days),
        COUNT(*) FILTER (WHERE has_usable_review)::integer,
        COUNT(*) FILTER (WHERE is_negative_review)::integer,
        COUNT(*) FILTER (WHERE is_negative_review)::numeric
            / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0),
        COUNT(*) FILTER (WHERE is_delivered AND has_usable_review)::numeric
            / NULLIF(COUNT(*) FILTER (WHERE is_delivered), 0)
    FROM metrics.kpi_orders
    WHERE is_comparable_trend_window
),
watchlist AS (
    SELECT
        COUNT(*)::integer AS watchlist_sellers,
        COUNT(*) FILTER (WHERE is_high_excess)::integer AS high_excess_sellers,
        COUNT(*) FILTER (
            WHERE is_recently_deteriorating AND NOT is_high_excess
        )::integer AS monitor_only_sellers,
        SUM(delivery_eligible_seller_orders)::integer AS watchlist_eligible_seller_orders,
        SUM(late_seller_orders)::integer AS watchlist_late_seller_orders,
        SUM(seller_late_contribution) AS watchlist_late_contribution,
        SUM(late_seller_orders)::numeric
            / NULLIF(SUM(delivery_eligible_seller_orders), 0) AS watchlist_pooled_late_rate
    FROM analysis.seller_watchlist
),
cx AS (
    SELECT
        MAX(reviewed_orders) FILTER (WHERE delivery_class = 'early') AS early_reviewed_orders,
        MAX(reviewed_orders) FILTER (WHERE delivery_class = 'late') AS late_reviewed_orders,
        MAX(negative_review_rate) FILTER (WHERE delivery_class = 'early') AS early_negative_review_rate,
        MAX(negative_review_rate) FILTER (WHERE delivery_class = 'late') AS late_negative_review_rate
    FROM analysis.delivery_class_review_rates
)
SELECT
    s.*,
    w.*,
    c.*,
    c.late_negative_review_rate - c.early_negative_review_rate
        AS late_vs_early_negative_review_pp
FROM scope_metrics s
CROSS JOIN watchlist w
CROSS JOIN cx c;

CREATE VIEW dashboard.delivery_review AS
SELECT
    delivery_class,
    'order'::text AS unit_grain,
    classified_delivered_orders,
    reviewed_orders,
    without_usable_review,
    negative_review_orders,
    negative_review_rate,
    avg_review_score,
    gmv
FROM analysis.delivery_class_review_rates;

CREATE VIEW dashboard.delay_band_reviews AS
SELECT
    delay_band,
    delay_band_sort,
    'order'::text AS unit_grain,
    eligible_orders,
    reviewed_orders,
    without_usable_review,
    negative_review_orders,
    negative_review_rate,
    avg_review_score,
    median_review_score,
    gmv,
    is_low_sample
FROM analysis.delay_band_reviews;
