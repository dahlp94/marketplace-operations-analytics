-- Independent window checks.

-- Marketplace LAG: March 2017 vs February 2017.
WITH rates AS (
    SELECT
        MAX(late_delivery_rate) FILTER (
            WHERE purchase_month = DATE '2017-02-01'
        ) AS feb_rate,
        MAX(late_delivery_rate) FILTER (
            WHERE purchase_month = DATE '2017-03-01'
        ) AS mar_rate
    FROM metrics.kpi_marketplace_month
)
SELECT
    'lag_spot_check' AS check_name,
    ROUND(r.feb_rate, 10) = ROUND(t.prior_late_delivery_rate, 10)
        AS prior_matches,
    ROUND(r.mar_rate - r.feb_rate, 10) = ROUND(t.late_rate_pp_change, 10)
        AS change_matches
FROM rates r
JOIN analysis.marketplace_month_trend t
    ON t.purchase_month = DATE '2017-03-01';

SELECT
    'first_comparable_lag_null' AS check_name,
    comparable_prior_late_delivery_rate IS NULL AS matches
FROM analysis.marketplace_month_trend
WHERE purchase_month = DATE '2017-02-01';

-- Marketplace 30-day and 90-day windows on 2018-05-15.
WITH counts AS (
    SELECT
        COUNT(*) FILTER (
            WHERE purchase_date >= DATE '2018-05-15' - 29 AND is_late
        ) AS late_30d,
        COUNT(*) FILTER (
            WHERE purchase_date >= DATE '2018-05-15' - 29
              AND is_delivery_performance_eligible
        ) AS eligible_30d,
        COUNT(*) FILTER (WHERE is_late) AS late_90d,
        COUNT(*) FILTER (
            WHERE is_delivery_performance_eligible
        ) AS eligible_90d
    FROM metrics.kpi_orders
    WHERE purchase_date BETWEEN DATE '2018-05-15' - 89
                            AND DATE '2018-05-15'
)
SELECT
    'rolling_window_spot_check' AS check_name,
    c.late_30d = d.late_count_30d
        AND c.eligible_30d = d.eligible_count_30d AS matches_30d,
    c.late_90d = d.late_count_90d
        AND c.eligible_90d = d.eligible_count_90d AS matches_90d,
    d.late_count_30d,
    d.eligible_count_30d,
    d.late_count_90d,
    d.eligible_count_90d
FROM counts c
JOIN analysis.marketplace_day d
    ON d.purchase_date = DATE '2018-05-15';

-- Seller 30-day window for one observed seller.
WITH sample AS (
    SELECT MIN(seller_id) AS seller_id
    FROM analysis.seller_day_rolling
    WHERE purchase_date = DATE '2018-05-15'
),
counts AS (
    SELECT
        COUNT(*) FILTER (WHERE s.is_late) AS late_count,
        COUNT(*) FILTER (
            WHERE s.is_delivery_performance_eligible
        ) AS eligible_count
    FROM metrics.kpi_seller_orders s
    JOIN sample x ON x.seller_id = s.seller_id
    WHERE s.purchase_date BETWEEN DATE '2018-05-15' - 29
                              AND DATE '2018-05-15'
)
SELECT
    'seller_rolling_30d_spot_check' AS check_name,
    x.seller_id,
    c.late_count = r.late_count_30d
        AND c.eligible_count = r.eligible_count_30d AS matches
FROM sample x
CROSS JOIN counts c
JOIN analysis.seller_day_rolling r
    ON r.seller_id = x.seller_id
   AND r.purchase_date = DATE '2018-05-15';
