-- Independent checks for trends, windows, rankings, customers, and reviews.

-- Monthly totals and selected LAG behavior.
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', purchase_date)::date AS purchase_month,
        COUNT(*) AS all_orders,
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
        ) AS late_count
    FROM analytics.fact_orders
    GROUP BY 1
),
lagged AS (
    SELECT
        purchase_month,
        late_count::numeric / NULLIF(eligible, 0) AS late_rate,
        LAG(late_count::numeric / NULLIF(eligible, 0))
            OVER (ORDER BY purchase_month) AS prior_rate
    FROM monthly
)
SELECT
    NOT EXISTS (
        SELECT 1
        FROM monthly m
        JOIN metrics.kpi_marketplace_month k USING (purchase_month)
        WHERE m.all_orders IS DISTINCT FROM k.all_orders
           OR m.eligible IS DISTINCT FROM k.delivery_performance_eligible
           OR m.late_count IS DISTINCT FROM k.late_count
    ) AS monthly_totals_match,
    (SELECT comparable_prior_late_delivery_rate IS NULL
     FROM analysis.marketplace_month_trend
     WHERE purchase_month = DATE '2017-02-01')
        AS first_comparable_prior_null,
    (SELECT ROUND(l.late_rate - l.prior_rate, 10)
                = ROUND(a.late_rate_pp_change, 10)
     FROM lagged l
     JOIN analysis.marketplace_month_trend a USING (purchase_month)
     WHERE l.purchase_month = DATE '2017-03-01')
        AS march_lag_match;


-- Marketplace 30/90-day windows on a fixed date.
WITH expected AS (
    SELECT
        COUNT(*) FILTER (
            WHERE purchase_date >= DATE '2018-05-15' - 29
              AND order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  > order_estimated_delivery_date::date
        ) AS late_30d,
        COUNT(*) FILTER (
            WHERE purchase_date >= DATE '2018-05-15' - 29
              AND order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
        ) AS eligible_30d,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  > order_estimated_delivery_date::date
        ) AS late_90d,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
        ) AS eligible_90d
    FROM analytics.fact_orders
    WHERE purchase_date BETWEEN DATE '2018-05-15' - 89
                            AND DATE '2018-05-15'
)
SELECT
    e.late_30d = a.late_count_30d
        AND e.eligible_30d = a.eligible_count_30d AS rolling_30d_match,
    e.late_90d = a.late_count_90d
        AND e.eligible_90d = a.eligible_count_90d AS rolling_90d_match,
    a.is_full_30d_window AND a.is_full_90d_window AS full_windows
FROM expected e
JOIN analysis.marketplace_day a
    ON a.purchase_date = DATE '2018-05-15';


-- Extract-start windows must be partial.
SELECT
    NOT is_full_30d_window AND NOT is_full_90d_window
        AS start_windows_are_partial
FROM analysis.marketplace_day
WHERE purchase_date = (SELECT MIN(purchase_date) FROM analytics.fact_orders);


-- Seller 30-day window for one high-volume seller.
WITH sample AS (
    SELECT seller_id
    FROM analysis.seller_day_rolling
    WHERE purchase_date = DATE '2018-05-15'
    ORDER BY seller_order_volume DESC, seller_id
    LIMIT 1
),
seller_orders AS (
    SELECT DISTINCT
        i.seller_id,
        i.order_id,
        o.order_status,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM analytics.fact_order_items i
    JOIN analytics.fact_orders o USING (order_id)
    JOIN sample s USING (seller_id)
    WHERE o.purchase_date BETWEEN DATE '2018-05-15' - 29
                              AND DATE '2018-05-15'
),
expected AS (
    SELECT
        seller_id,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  > order_estimated_delivery_date::date
        ) AS late_30d,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
        ) AS eligible_30d
    FROM seller_orders
    GROUP BY seller_id
)
SELECT
    e.late_30d = a.late_count_30d
        AND e.eligible_30d = a.eligible_count_30d AS seller_rolling_match
FROM expected e
JOIN analysis.seller_day_rolling a
  ON a.seller_id = e.seller_id
 AND a.purchase_date = DATE '2018-05-15';


-- Reproduce ranking semantics from the seller KPI table.
WITH ranked AS (
    SELECT
        seller_id,
        RANK() OVER (
            ORDER BY seller_late_rate DESC NULLS LAST
        ) AS late_rate_rank,
        DENSE_RANK() OVER (
            ORDER BY seller_late_rate DESC NULLS LAST
        ) AS late_rate_dense_rank,
        ROW_NUMBER() OVER (
            ORDER BY seller_late_rate DESC NULLS LAST,
                     delivery_eligible_seller_orders DESC,
                     seller_id
        ) AS late_rate_row_number
    FROM metrics.kpi_sellers
)
SELECT
    COUNT(*) FILTER (
        WHERE r.late_rate_rank IS DISTINCT FROM a.late_rate_rank
    ) AS rank_mismatches,
    COUNT(*) FILTER (
        WHERE r.late_rate_dense_rank IS DISTINCT FROM a.late_rate_dense_rank
    ) AS dense_rank_mismatches,
    COUNT(*) FILTER (
        WHERE r.late_rate_row_number IS DISTINCT FROM a.late_rate_row_number
    ) AS row_number_mismatches,
    COUNT(*) FILTER (
        WHERE a.delivery_eligible_seller_orders = 1
    ) AS one_order_sellers_visible
FROM ranked r
JOIN analysis.seller_rankings a USING (seller_id);


-- Full-population repeat-order sequence.
WITH independent AS (
    SELECT
        o.order_id,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS sequence
    FROM analytics.fact_orders o
    JOIN analytics.dim_customer c USING (customer_id)
)
SELECT
    COUNT(*) FILTER (
        WHERE i.sequence IS DISTINCT FROM k.customer_order_sequence
    ) AS sequence_mismatches,
    COUNT(*) FILTER (WHERE i.sequence > 1)
        = (SELECT repeat_orders FROM metrics.kpi_marketplace)
        AS repeat_total_match
FROM independent i
JOIN metrics.kpi_orders k USING (order_id);


-- Review denominator and bands.
SELECT
    COUNT(*) FILTER (
        WHERE NOT has_usable_review
          AND is_negative_review IS NOT NULL
    ) AS invalid_unreviewed_flags,
    COUNT(*) FILTER (WHERE has_usable_review)
        = (SELECT COUNT(*)
           FROM analytics.fact_orders
           WHERE n_usable_review_rows > 0)
        AS reviewed_total_match,
    COUNT(*) FILTER (WHERE is_negative_review)
        = (SELECT COUNT(*)
           FROM analytics.fact_orders
           WHERE n_usable_review_rows > 0
             AND order_review_score <= 2)
        AS negative_total_match
FROM metrics.kpi_orders;


SELECT
    COUNT(*) FILTER (
        WHERE b.n_orders <> (
            SELECT COUNT(*)
            FROM analytics.fact_orders f
            WHERE f.n_usable_review_rows > 0
              AND CASE
                    WHEN f.order_review_score <= 2 THEN 'negative'
                    WHEN f.order_review_score < 4 THEN 'neutral'
                    ELSE 'positive'
                  END = b.review_band
        )
    ) = 0 AS review_bands_match
FROM metrics.kpi_review_bands b;


SELECT
    SUM(n_orders)
        = (SELECT COUNT(*) FROM metrics.kpi_orders WHERE is_delivered)
        AS delivery_review_mix_match,
    SUM(n_orders) FILTER (WHERE review_status = 'no_usable_review')
        AS delivered_without_usable_review
FROM analysis.delivery_review_mix;
