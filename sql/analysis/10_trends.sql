-- Month-over-month marketplace and seller trends.
-- Rate changes are percentage-point changes.

DROP TABLE IF EXISTS analysis.marketplace_month_trend;
DROP TABLE IF EXISTS analysis.seller_month;

CREATE TABLE analysis.marketplace_month_trend AS
WITH monthly AS (
    SELECT
        r.purchase_month,
        r.is_comparable_trend_window,
        r.coverage_class,
        COALESCE(m.all_orders, 0) AS all_orders,
        COALESCE(m.delivered_orders, 0) AS delivered_orders,
        COALESCE(m.delivery_performance_eligible, 0)
            AS delivery_performance_eligible,
        COALESCE(m.late_count, 0) AS late_count,
        COALESCE(m.on_time_count, 0) AS on_time_count,
        m.late_delivery_rate,
        m.on_time_delivery_rate,
        COALESCE(m.gmv, 0) AS gmv,
        COALESCE(m.late_gmv, 0) AS late_gmv,
        m.review_coverage,
        m.negative_review_rate,
        COALESCE(m.repeat_orders, 0) AS repeat_orders
    FROM analysis.reporting_month r
    LEFT JOIN metrics.kpi_marketplace_month m USING (purchase_month)
),
lagged AS (
    SELECT
        *,
        LAG(late_delivery_rate) OVER (
            ORDER BY purchase_month
        ) AS prior_late_delivery_rate,
        LAG(late_count) OVER (
            ORDER BY purchase_month
        ) AS prior_late_count,
        LAG(all_orders) OVER (
            ORDER BY purchase_month
        ) AS prior_all_orders,
        LAG(negative_review_rate) OVER (
            ORDER BY purchase_month
        ) AS prior_negative_review_rate,
        LAG(review_coverage) OVER (
            ORDER BY purchase_month
        ) AS prior_review_coverage,
        CASE
            WHEN is_comparable_trend_window THEN
                LAG(late_delivery_rate) OVER (
                    PARTITION BY is_comparable_trend_window
                    ORDER BY purchase_month
                )
        END AS comparable_prior_late_delivery_rate
    FROM monthly
)
SELECT
    purchase_month,
    is_comparable_trend_window,
    coverage_class,
    all_orders,
    delivered_orders,
    delivery_performance_eligible,
    late_count,
    on_time_count,
    late_delivery_rate,
    on_time_delivery_rate,
    gmv,
    late_gmv,
    review_coverage,
    negative_review_rate,
    repeat_orders,
    prior_late_delivery_rate,
    late_delivery_rate - prior_late_delivery_rate AS late_rate_pp_change,
    late_count - prior_late_count AS late_count_change,
    all_orders - prior_all_orders AS order_volume_change,
    comparable_prior_late_delivery_rate,
    late_delivery_rate - comparable_prior_late_delivery_rate
        AS comparable_late_rate_pp_change,
    prior_negative_review_rate,
    negative_review_rate - prior_negative_review_rate
        AS negative_review_rate_pp_change,
    prior_review_coverage,
    review_coverage - prior_review_coverage AS review_coverage_pp_change
FROM lagged;


CREATE TABLE analysis.seller_month AS
WITH monthly AS (
    SELECT
        seller_id,
        purchase_month,
        BOOL_OR(is_comparable_trend_window) AS is_comparable_trend_window,
        COUNT(*)::INTEGER AS seller_order_volume,
        COUNT(*) FILTER (
            WHERE is_delivery_performance_eligible
        )::INTEGER AS delivery_eligible_seller_orders,
        COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_seller_orders,
        COUNT(*) FILTER (WHERE is_on_time)::INTEGER AS on_time_seller_orders,
        SUM(seller_gmv) AS seller_gmv,
        SUM(seller_late_gmv) AS seller_late_gmv,
        COUNT(*) FILTER (WHERE has_usable_review)::INTEGER AS reviewed_seller_orders,
        COUNT(*) FILTER (
            WHERE is_negative_review
        )::INTEGER AS negative_review_seller_orders
    FROM metrics.kpi_seller_orders
    GROUP BY seller_id, purchase_month
),
rates AS (
    SELECT
        *,
        late_seller_orders::NUMERIC
            / NULLIF(delivery_eligible_seller_orders, 0) AS seller_late_rate,
        negative_review_seller_orders::NUMERIC
            / NULLIF(reviewed_seller_orders, 0) AS seller_negative_review_rate
    FROM monthly
),
lagged AS (
    SELECT
        *,
        LAG(purchase_month) OVER (
            PARTITION BY seller_id ORDER BY purchase_month
        ) AS prior_purchase_month,
        LAG(seller_late_rate) OVER (
            PARTITION BY seller_id ORDER BY purchase_month
        ) AS prior_seller_late_rate,
        LAG(seller_order_volume) OVER (
            PARTITION BY seller_id ORDER BY purchase_month
        ) AS prior_seller_order_volume
    FROM rates
)
SELECT
    seller_id,
    purchase_month,
    is_comparable_trend_window,
    seller_order_volume,
    delivery_eligible_seller_orders,
    late_seller_orders,
    on_time_seller_orders,
    seller_late_rate,
    seller_gmv,
    seller_late_gmv,
    reviewed_seller_orders,
    negative_review_seller_orders,
    seller_negative_review_rate,
    prior_seller_late_rate,
    seller_late_rate - prior_seller_late_rate AS seller_late_rate_pp_change,
    seller_order_volume - prior_seller_order_volume AS seller_order_volume_change,
    (
        DATE_PART('year', AGE(purchase_month, prior_purchase_month)) * 12
        + DATE_PART('month', AGE(purchase_month, prior_purchase_month))
    )::INTEGER AS months_since_prior_activity
FROM lagged;
