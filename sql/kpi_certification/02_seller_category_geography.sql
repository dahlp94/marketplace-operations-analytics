-- Seller, category, and geography reconciliation.

\set QUIET on
CREATE TEMP TABLE independent_sellers AS
WITH seller_orders AS (
    SELECT seller_id, order_id, SUM(price) AS seller_gmv
    FROM analytics.fact_order_items
    GROUP BY seller_id, order_id
),
classified AS (
    SELECT
        s.*,
        o.order_status = 'delivered'
            AND o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL AS is_eligible,
        o.order_status = 'delivered'
            AND o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL
            AND o.order_delivered_customer_date::date
                > o.order_estimated_delivery_date::date AS is_late
    FROM seller_orders s
    JOIN analytics.fact_orders o USING (order_id)
)
SELECT
    d.seller_id,
    COUNT(c.order_id)::integer AS seller_order_volume,
    COUNT(c.order_id) FILTER (WHERE c.is_eligible)::integer
        AS eligible_seller_orders,
    COUNT(c.order_id) FILTER (WHERE c.is_late)::integer AS late_seller_orders,
    SUM(c.seller_gmv) AS seller_gmv,
    SUM(c.seller_gmv) FILTER (WHERE c.is_late) AS seller_late_gmv
FROM analytics.dim_seller d
LEFT JOIN classified c USING (seller_id)
GROUP BY d.seller_id;
\set QUIET off


-- Seller totals and the multi-seller late-order difference.
WITH late AS (
    SELECT
        COUNT(*) AS late_orders,
        COALESCE(SUM(n_sellers - 1) FILTER (WHERE n_sellers > 1), 0)
            AS extra_seller_units
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date::date
          > order_estimated_delivery_date::date
)
SELECT
    SUM(i.late_seller_orders) = l.late_orders + l.extra_seller_units
        AS late_units_explained,
    SUM(i.late_seller_orders)
        = (SELECT SUM(late_seller_orders) FROM metrics.kpi_sellers)
        AS late_units_match,
    ROUND(SUM(i.seller_gmv), 2)
        = ROUND((SELECT SUM(price) FROM analytics.fact_order_items), 2)
        AS seller_gmv_matches_items,
    ROUND(SUM(i.seller_gmv), 2)
        = ROUND((SELECT SUM(seller_gmv) FROM metrics.kpi_sellers), 2)
        AS seller_gmv_matches_kpi,
    ROUND((SELECT SUM(seller_late_contribution)
           FROM metrics.kpi_sellers), 10) = 1
        AS contribution_sums_to_one
FROM independent_sellers i
CROSS JOIN late l
GROUP BY l.late_orders, l.extra_seller_units;


-- Seller-level comparison.
SELECT
    COUNT(*) FILTER (
        WHERE i.late_seller_orders IS DISTINCT FROM k.late_seller_orders
    ) AS late_count_mismatches,
    COUNT(*) FILTER (
        WHERE i.eligible_seller_orders
            IS DISTINCT FROM k.delivery_eligible_seller_orders
    ) AS eligible_mismatches,
    COUNT(*) FILTER (
        WHERE ROUND(COALESCE(i.seller_gmv, 0), 2)
            IS DISTINCT FROM ROUND(COALESCE(k.seller_gmv, 0), 2)
    ) AS gmv_mismatches,
    COUNT(*) FILTER (
        WHERE ROUND(
            i.late_seller_orders::numeric / NULLIF(i.eligible_seller_orders, 0),
            10
        ) IS DISTINCT FROM ROUND(k.seller_late_rate, 10)
    ) AS late_rate_mismatches
FROM independent_sellers i
JOIN metrics.kpi_sellers k USING (seller_id);


-- Category GMV is additive; late category counts are intentionally not.
WITH category_orders AS (
    SELECT
        i.seller_id,
        i.order_id,
        p.product_category,
        SUM(i.price) AS category_gmv
    FROM analytics.fact_order_items i
    JOIN analytics.dim_product p USING (product_id)
    GROUP BY i.seller_id, i.order_id, p.product_category
),
late_orders AS (
    SELECT order_id
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date::date
          > order_estimated_delivery_date::date
)
SELECT
    ROUND(SUM(c.category_gmv), 2)
        = (SELECT gmv FROM metrics.kpi_marketplace) AS category_gmv_match,
    ROUND(SUM(c.category_gmv), 2)
        = ROUND((SELECT SUM(seller_category_gmv)
                 FROM analysis.seller_category), 2)
        AS analysis_category_gmv_match,
    (SELECT COUNT(*) FROM category_orders JOIN late_orders USING (order_id))
        <> (SELECT SUM(late_seller_orders) FROM metrics.kpi_sellers)
        AS category_late_counts_non_additive
FROM category_orders c;


-- Geography totals and join stability.
SELECT
    (SELECT SUM(all_orders) FROM analysis.customer_state_performance)
        = (SELECT COUNT(*) FROM analytics.fact_orders)
        AS customer_orders_match,
    (SELECT ROUND(SUM(gmv), 2)
     FROM analysis.customer_state_performance)
        = (SELECT gmv FROM metrics.kpi_marketplace)
        AS customer_gmv_match,
    (SELECT SUM(seller_order_volume)
     FROM analysis.seller_state_performance)
        = (SELECT COUNT(*) FROM metrics.kpi_seller_orders)
        AS seller_units_match,
    (SELECT ROUND(SUM(seller_gmv), 2)
     FROM analysis.seller_state_performance)
        = (SELECT gmv FROM metrics.kpi_marketplace)
        AS seller_gmv_match,
    (SELECT COUNT(*) FROM metrics.kpi_orders)
        = (
            SELECT COUNT(*)
            FROM metrics.kpi_orders o
            JOIN analytics.dim_customer c USING (customer_id)
            LEFT JOIN analytics.dim_geography g
                ON g.zip_code_prefix = c.zip_code_prefix
        ) AS geography_join_stable;
