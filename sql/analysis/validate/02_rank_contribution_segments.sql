-- Ranking, contribution, and segment checks.

-- Tied late rates share RANK/DENSE_RANK; ROW_NUMBER stays unique.
WITH tied AS (
    SELECT
        seller_late_rate,
        COUNT(*) AS n_sellers,
        COUNT(DISTINCT late_rate_rank) AS n_ranks,
        COUNT(DISTINCT late_rate_dense_rank) AS n_dense_ranks,
        COUNT(DISTINCT late_rate_row_number) AS n_row_numbers
    FROM analysis.seller_rankings
    WHERE seller_late_rate IS NOT NULL
    GROUP BY seller_late_rate
    HAVING COUNT(*) > 1
    ORDER BY n_sellers DESC
    LIMIT 1
)
SELECT
    'rank_tie_behavior' AS check_name,
    n_ranks = 1 AS rank_shared,
    n_dense_ranks = 1 AS dense_rank_shared,
    n_row_numbers = n_sellers AS row_number_unique
FROM tied;

-- Contribution totals and cumulative order.
WITH x AS (
    SELECT
        *,
        cumulative_late_contribution - LAG(cumulative_late_contribution)
            OVER (ORDER BY contribution_row_number) AS step
    FROM analysis.seller_contribution
)
SELECT
    'contribution_reconciliation' AS check_name,
    ROUND(SUM(seller_late_contribution), 10) AS contribution_sum,
    SUM(late_seller_orders) AS late_seller_orders,
    COUNT(*) FILTER (WHERE step < 0) AS negative_steps,
    ROUND(SUM(seller_late_contribution), 10) = 1 AS sums_to_one,
    MAX(cumulative_late_contribution) = 1 AS cumulative_ends_at_one
FROM x;

SELECT *
FROM analysis.contribution_concentration;

-- Category totals and partitioned ranks.
WITH category AS (
    SELECT
        ROUND(SUM(seller_category_gmv), 2) AS gmv,
        COUNT(*) FILTER (WHERE is_largest_gmv_category) AS largest_count,
        COUNT(*) FILTER (WHERE late_rate_rank_in_category = 1) AS top_ranks,
        COUNT(DISTINCT product_category) AS categories
    FROM analysis.seller_category
)
SELECT
    'category_reconciliation' AS check_name,
    c.gmv = ROUND((SELECT SUM(gmv) FROM metrics.kpi_orders), 2) AS gmv_matches,
    c.largest_count = (SELECT COUNT(*) FROM analytics.dim_seller)
        AS one_largest_per_seller,
    c.top_ranks,
    c.categories
FROM category c;

-- Repeat-order counts.
SELECT
    'repeat_reconciliation' AS check_name,
    SUM(all_orders) = (SELECT COUNT(*) FROM metrics.kpi_orders) AS orders_match,
    SUM(all_orders) FILTER (WHERE is_repeat_order) = (
        SELECT COUNT(*) FROM metrics.kpi_orders WHERE is_repeat_order
    ) AS repeat_match
FROM analysis.repeat_order_performance;

-- Geographic aggregates.
SELECT
    'customer_state_reconciliation' AS check_name,
    SUM(all_orders) = (SELECT COUNT(*) FROM metrics.kpi_orders) AS orders_match,
    ROUND(SUM(gmv), 2) = (
        SELECT ROUND(SUM(gmv), 2) FROM metrics.kpi_orders
    ) AS gmv_match
FROM analysis.customer_state_performance;

SELECT
    'seller_state_reconciliation' AS check_name,
    SUM(seller_order_volume) = (
        SELECT COUNT(*) FROM metrics.kpi_seller_orders
    ) AS matches
FROM analysis.seller_state_performance;

-- Delivered-order review mix.
SELECT
    'delivery_review_mix' AS check_name,
    SUM(n_orders) = (
        SELECT COUNT(*) FROM metrics.kpi_orders WHERE is_delivered
    ) AS delivered_match,
    SUM(n_orders) FILTER (
        WHERE review_status = 'no_usable_review'
    ) AS no_usable_review_orders
FROM analysis.delivery_review_mix;

-- First-observed cohorts cover all sellers.
SELECT
    'cohort_coverage' AS check_name,
    SUM(n_sellers) = (SELECT COUNT(*) FROM analytics.dim_seller) AS matches
FROM analysis.seller_cohort_summary;
