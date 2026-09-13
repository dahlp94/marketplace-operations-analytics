-- Monthly trends, fulfillment components, and rolling monitoring metrics.

CREATE VIEW dashboard.fulfillment_trends AS
WITH benchmarks AS (
    SELECT
        SUM(late_count) FILTER (WHERE is_comparable_trend_window)::numeric
            / NULLIF(SUM(delivery_performance_eligible) FILTER (WHERE is_comparable_trend_window), 0)
            AS comparable_window_late_rate,
        SUM(late_count) FILTER (
            WHERE purchase_month >= DATE '2017-02-01'
              AND purchase_month < DATE '2017-09-01'
        )::numeric
            / NULLIF(SUM(delivery_performance_eligible) FILTER (
                WHERE purchase_month >= DATE '2017-02-01'
                  AND purchase_month < DATE '2017-09-01'
            ), 0) AS early_2017_baseline_late_rate
    FROM analysis.marketplace_month_trend
)
SELECT
    t.purchase_month,
    t.is_comparable_trend_window,
    t.coverage_class,
    'order'::text AS unit_grain,
    t.all_orders,
    t.delivered_orders,
    t.delivery_performance_eligible,
    t.on_time_count,
    t.late_count,
    t.on_time_delivery_rate,
    t.late_delivery_rate,
    t.gmv,
    t.late_gmv,
    t.negative_review_rate,
    t.review_coverage,
    t.prior_late_delivery_rate,
    t.late_rate_pp_change,
    t.comparable_prior_late_delivery_rate,
    t.comparable_late_rate_pp_change,
    t.negative_review_rate_pp_change,
    f.seller_handling_eligible,
    f.avg_seller_handling_days,
    f.median_seller_handling_days,
    f.p90_seller_handling_days,
    f.carrier_transit_eligible,
    f.avg_carrier_transit_days,
    f.median_carrier_transit_days,
    f.p90_carrier_transit_days,
    f.promised_window_eligible,
    f.avg_promised_window_days,
    f.median_promised_window_days,
    f.purchase_to_delivery_eligible,
    f.avg_purchase_to_delivery_days,
    f.median_purchase_to_delivery_days,
    f.avg_delivery_delay_days,
    f.median_delivery_delay_days,
    f.p90_delivery_delay_days,
    b.comparable_window_late_rate,
    b.early_2017_baseline_late_rate,
    t.late_delivery_rate - b.comparable_window_late_rate AS late_rate_vs_window_pp,
    t.late_delivery_rate - b.early_2017_baseline_late_rate AS late_rate_vs_baseline_pp
FROM analysis.marketplace_month_trend t
JOIN analysis.fulfillment_month f USING (purchase_month)
CROSS JOIN benchmarks b;

CREATE VIEW dashboard.fulfillment_components AS
SELECT
    analysis_period,
    delivery_class,
    'order'::text AS unit_grain,
    eligible_orders,
    seller_handling_eligible,
    carrier_transit_eligible,
    purchase_to_delivery_eligible,
    avg_seller_handling_days,
    median_seller_handling_days,
    avg_carrier_transit_days,
    median_carrier_transit_days,
    avg_purchase_to_delivery_days,
    median_purchase_to_delivery_days,
    avg_promised_window_days,
    median_promised_window_days,
    avg_delivery_delay_days,
    median_delivery_delay_days,
    gmv,
    late_gmv
FROM analysis.fulfillment_decomposition;

CREATE VIEW dashboard.marketplace_rolling AS
SELECT
    purchase_date,
    is_comparable_trend_window,
    is_full_30d_window,
    is_full_90d_window,
    'order'::text AS unit_grain,
    all_orders,
    delivery_performance_eligible,
    late_count,
    on_time_count,
    late_delivery_rate,
    gmv,
    late_gmv,
    late_count_30d,
    eligible_count_30d,
    late_rate_30d,
    order_volume_30d,
    negative_review_rate_30d,
    late_count_90d,
    eligible_count_90d,
    late_rate_90d,
    order_volume_90d,
    negative_review_rate_90d
FROM analysis.marketplace_day;
