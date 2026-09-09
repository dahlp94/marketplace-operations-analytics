-- Rolling 30-day and 90-day calendar windows.
-- Rates use summed numerators divided by summed denominators.

DROP TABLE IF EXISTS analysis.marketplace_day;
DROP TABLE IF EXISTS analysis.seller_day_rolling;

CREATE TABLE analysis.marketplace_day AS
WITH bounds AS (
    SELECT MIN(purchase_date) AS first_date, MAX(purchase_date) AS last_date
    FROM metrics.kpi_orders
),
calendar AS (
    SELECT day::date AS purchase_date
    FROM bounds
    CROSS JOIN LATERAL generate_series(
        first_date,
        last_date,
        INTERVAL '1 day'
    ) AS day
),
daily AS (
    SELECT
        purchase_date,
        COUNT(*)::INTEGER AS all_orders,
        COUNT(*) FILTER (
            WHERE is_delivery_performance_eligible
        )::INTEGER AS delivery_performance_eligible,
        COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_count,
        COUNT(*) FILTER (WHERE is_on_time)::INTEGER AS on_time_count,
        COUNT(*) FILTER (WHERE has_usable_review)::INTEGER AS reviewed_orders,
        COUNT(*) FILTER (
            WHERE is_negative_review
        )::INTEGER AS negative_review_count,
        SUM(gmv) AS gmv,
        SUM(late_gmv) AS late_gmv
    FROM metrics.kpi_orders
    GROUP BY purchase_date
),
filled AS (
    SELECT
        c.purchase_date,
        b.first_date,
        c.purchase_date >= DATE '2017-02-01'
            AND c.purchase_date < DATE '2018-09-01'
            AS is_comparable_trend_window,
        COALESCE(d.all_orders, 0) AS all_orders,
        COALESCE(d.delivery_performance_eligible, 0)
            AS delivery_performance_eligible,
        COALESCE(d.late_count, 0) AS late_count,
        COALESCE(d.on_time_count, 0) AS on_time_count,
        COALESCE(d.reviewed_orders, 0) AS reviewed_orders,
        COALESCE(d.negative_review_count, 0) AS negative_review_count,
        COALESCE(d.gmv, 0) AS gmv,
        COALESCE(d.late_gmv, 0) AS late_gmv
    FROM calendar c
    CROSS JOIN bounds b
    LEFT JOIN daily d USING (purchase_date)
),
rolling AS (
    SELECT
        *,
        SUM(late_count) OVER w30 AS late_count_30d,
        SUM(delivery_performance_eligible) OVER w30 AS eligible_count_30d,
        SUM(all_orders) OVER w30 AS order_volume_30d,
        SUM(negative_review_count) OVER w30 AS negative_reviews_30d,
        SUM(reviewed_orders) OVER w30 AS reviewed_orders_30d,
        SUM(late_count) OVER w90 AS late_count_90d,
        SUM(delivery_performance_eligible) OVER w90 AS eligible_count_90d,
        SUM(all_orders) OVER w90 AS order_volume_90d,
        SUM(negative_review_count) OVER w90 AS negative_reviews_90d,
        SUM(reviewed_orders) OVER w90 AS reviewed_orders_90d
    FROM filled
    WINDOW
        w30 AS (
            ORDER BY purchase_date
            RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW
        ),
        w90 AS (
            ORDER BY purchase_date
            RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW
        )
)
SELECT
    purchase_date,
    is_comparable_trend_window,
    purchase_date >= first_date + 29 AS is_full_30d_window,
    purchase_date >= first_date + 89 AS is_full_90d_window,
    all_orders,
    delivery_performance_eligible,
    late_count,
    on_time_count,
    reviewed_orders,
    negative_review_count,
    gmv,
    late_gmv,
    late_count::NUMERIC / NULLIF(delivery_performance_eligible, 0)
        AS late_delivery_rate,
    late_count_30d,
    eligible_count_30d,
    late_count_30d::NUMERIC / NULLIF(eligible_count_30d, 0) AS late_rate_30d,
    order_volume_30d,
    negative_reviews_30d::NUMERIC / NULLIF(reviewed_orders_30d, 0)
        AS negative_review_rate_30d,
    late_count_90d,
    eligible_count_90d,
    late_count_90d::NUMERIC / NULLIF(eligible_count_90d, 0) AS late_rate_90d,
    order_volume_90d,
    negative_reviews_90d::NUMERIC / NULLIF(reviewed_orders_90d, 0)
        AS negative_review_rate_90d
FROM rolling;


CREATE TABLE analysis.seller_day_rolling AS
WITH daily AS (
    SELECT
        seller_id,
        purchase_date,
        COUNT(*)::INTEGER AS seller_order_volume,
        COUNT(*) FILTER (
            WHERE is_delivery_performance_eligible
        )::INTEGER AS delivery_eligible_seller_orders,
        COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_seller_orders,
        SUM(seller_gmv) AS seller_gmv,
        COUNT(*) FILTER (WHERE has_usable_review)::INTEGER AS reviewed_seller_orders,
        COUNT(*) FILTER (
            WHERE is_negative_review
        )::INTEGER AS negative_review_seller_orders
    FROM metrics.kpi_seller_orders
    GROUP BY seller_id, purchase_date
),
rolling AS (
    SELECT
        *,
        SUM(late_seller_orders) OVER w30 AS late_count_30d,
        SUM(delivery_eligible_seller_orders) OVER w30 AS eligible_count_30d,
        SUM(seller_order_volume) OVER w30 AS seller_order_volume_30d,
        SUM(late_seller_orders) OVER w90 AS late_count_90d,
        SUM(delivery_eligible_seller_orders) OVER w90 AS eligible_count_90d,
        SUM(seller_order_volume) OVER w90 AS seller_order_volume_90d
    FROM daily
    WINDOW
        w30 AS (
            PARTITION BY seller_id
            ORDER BY purchase_date
            RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW
        ),
        w90 AS (
            PARTITION BY seller_id
            ORDER BY purchase_date
            RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW
        )
)
SELECT
    seller_id,
    purchase_date,
    seller_order_volume,
    delivery_eligible_seller_orders,
    late_seller_orders,
    seller_gmv,
    reviewed_seller_orders,
    negative_review_seller_orders,
    late_count_30d,
    eligible_count_30d,
    late_count_30d::NUMERIC / NULLIF(eligible_count_30d, 0)
        AS seller_late_rate_30d,
    seller_order_volume_30d,
    late_count_90d,
    eligible_count_90d,
    late_count_90d::NUMERIC / NULLIF(eligible_count_90d, 0)
        AS seller_late_rate_90d,
    seller_order_volume_90d
FROM rolling;
