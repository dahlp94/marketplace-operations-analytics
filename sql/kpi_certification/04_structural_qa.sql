-- Structural QA for metric and analysis outputs.

-- Grain uniqueness.
SELECT
    table_name,
    n_rows = n_keys AS grain_unique
FROM (
    SELECT 'metrics.kpi_orders' AS table_name,
           COUNT(*) AS n_rows, COUNT(DISTINCT order_id) AS n_keys
    FROM metrics.kpi_orders
    UNION ALL
    SELECT 'metrics.kpi_customers',
           COUNT(*), COUNT(DISTINCT customer_unique_id)
    FROM metrics.kpi_customers
    UNION ALL
    SELECT 'metrics.kpi_seller_orders',
           COUNT(*), COUNT(DISTINCT (seller_id, order_id))
    FROM metrics.kpi_seller_orders
    UNION ALL
    SELECT 'metrics.kpi_sellers',
           COUNT(*), COUNT(DISTINCT seller_id)
    FROM metrics.kpi_sellers
    UNION ALL
    SELECT 'analysis.marketplace_day',
           COUNT(*), COUNT(DISTINCT purchase_date)
    FROM analysis.marketplace_day
    UNION ALL
    SELECT 'analysis.seller_day_rolling',
           COUNT(*), COUNT(DISTINCT (seller_id, purchase_date))
    FROM analysis.seller_day_rolling
    UNION ALL
    SELECT 'analysis.seller_rankings',
           COUNT(*), COUNT(DISTINCT seller_id)
    FROM analysis.seller_rankings
    UNION ALL
    SELECT 'analysis.seller_contribution',
           COUNT(*), COUNT(DISTINCT contribution_row_number)
    FROM analysis.seller_contribution
    UNION ALL
    SELECT 'analysis.seller_category',
           COUNT(*), COUNT(DISTINCT (seller_id, product_category))
    FROM analysis.seller_category
    UNION ALL
    SELECT 'analysis.seller_month',
           COUNT(*), COUNT(DISTINCT (seller_id, purchase_month))
    FROM analysis.seller_month
) x
ORDER BY table_name;


-- Invalid values should all return zero.
SELECT check_name, n_bad, n_bad = 0 AS passes
FROM (
    SELECT 'null_order_keys' AS check_name,
           COUNT(*) FILTER (WHERE order_id IS NULL) AS n_bad
    FROM metrics.kpi_orders
    UNION ALL
    SELECT 'null_seller_keys',
           COUNT(*) FILTER (WHERE seller_id IS NULL)
    FROM metrics.kpi_sellers
    UNION ALL
    SELECT 'invalid_delivery_flags',
           COUNT(*) FILTER (
               WHERE is_delivery_performance_eligible
                 AND (is_on_time IS NULL
                      OR is_late IS NULL
                      OR is_on_time = is_late)
           )
    FROM metrics.kpi_orders
    UNION ALL
    SELECT 'invalid_seller_rates',
           COUNT(*) FILTER (
               WHERE seller_late_rate NOT BETWEEN 0 AND 1
           )
    FROM metrics.kpi_sellers
    UNION ALL
    SELECT 'invalid_contributions',
           COUNT(*) FILTER (
               WHERE seller_late_contribution NOT BETWEEN 0 AND 1
           )
    FROM metrics.kpi_sellers
    UNION ALL
    SELECT 'unreviewed_negative_flags',
           COUNT(*) FILTER (
               WHERE NOT has_usable_review
                 AND is_negative_review IS NOT NULL
           )
    FROM metrics.kpi_orders
    UNION ALL
    SELECT 'duration_when_ineligible',
           COUNT(*) FILTER (
               WHERE (NOT is_purchase_to_delivery_eligible
                      AND purchase_to_delivery_days IS NOT NULL)
                  OR (NOT is_seller_handling_eligible
                      AND seller_handling_days IS NOT NULL)
                  OR (NOT is_carrier_transit_eligible
                      AND carrier_transit_days IS NOT NULL)
                  OR (NOT is_delivery_performance_eligible
                      AND delivery_class IS NOT NULL)
           )
    FROM metrics.kpi_orders
    UNION ALL
    SELECT 'seller_order_orphans',
           COUNT(*)
    FROM metrics.kpi_seller_orders s
    LEFT JOIN metrics.kpi_orders o USING (order_id)
    LEFT JOIN analytics.dim_seller d USING (seller_id)
    WHERE o.order_id IS NULL OR d.seller_id IS NULL
    UNION ALL
    SELECT 'rolling_rates_out_of_bounds',
           COUNT(*) FILTER (
               WHERE late_rate_30d NOT BETWEEN 0 AND 1
                  OR late_rate_90d NOT BETWEEN 0 AND 1
           )
    FROM analysis.marketplace_day
    UNION ALL
    SELECT 'negative_contribution_steps',
           COUNT(*) FILTER (WHERE step < 0)
    FROM (
        SELECT
            cumulative_late_contribution
            - LAG(cumulative_late_contribution) OVER (
                ORDER BY contribution_row_number
            ) AS step
        FROM analysis.seller_contribution
    ) x
) checks
ORDER BY check_name;


-- Stable joins and contribution endpoint.
SELECT
    (SELECT COUNT(*) FROM analytics.fact_order_items)
        = (
            SELECT COUNT(*)
            FROM analytics.fact_order_items i
            JOIN analytics.dim_product p USING (product_id)
        ) AS item_product_join_stable,
    (SELECT COUNT(*) FROM analytics.fact_orders)
        = (
            SELECT COUNT(*)
            FROM analytics.fact_orders o
            JOIN analytics.dim_customer c USING (customer_id)
        ) AS order_customer_join_stable,
    (SELECT COUNT(*) FROM metrics.kpi_seller_orders)
        = (
            SELECT COUNT(*)
            FROM metrics.kpi_seller_orders s
            JOIN analytics.dim_seller d USING (seller_id)
        ) AS seller_join_stable,
    ROUND((SELECT SUM(seller_late_contribution)
           FROM analysis.seller_contribution), 10) = 1
        AS contribution_sums_to_one,
    (SELECT MAX(cumulative_late_contribution)
     FROM analysis.seller_contribution) = 1
        AS cumulative_ends_at_one;
