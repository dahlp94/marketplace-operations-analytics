-- Grain checks and key reconciliations for the KPI layer.

-- Expected grain uniqueness.
SELECT
    'kpi_orders' AS table_name,
    COUNT(*) = COUNT(DISTINCT order_id) AS is_unique
FROM metrics.kpi_orders

UNION ALL

SELECT
    'kpi_customers',
    COUNT(*) = COUNT(DISTINCT customer_unique_id)
FROM metrics.kpi_customers

UNION ALL

SELECT
    'kpi_seller_orders',
    COUNT(*) = COUNT(DISTINCT (seller_id, order_id))
FROM metrics.kpi_seller_orders

UNION ALL

SELECT
    'kpi_sellers',
    COUNT(*) = COUNT(DISTINCT seller_id)
FROM metrics.kpi_sellers

UNION ALL

SELECT
    'kpi_marketplace_month',
    COUNT(*) = COUNT(DISTINCT purchase_month)
FROM metrics.kpi_marketplace_month;


-- GMV reconciliation at full, eligible, and late populations.
WITH totals AS (
    SELECT
        ROUND((SELECT SUM(price)
               FROM analytics.fact_order_items), 2) AS item_gmv,
        ROUND((SELECT SUM(seller_gmv)
               FROM metrics.kpi_seller_orders), 2) AS seller_gmv,
        ROUND((SELECT SUM(gmv)
               FROM metrics.kpi_orders), 2) AS order_gmv,
        ROUND((SELECT SUM(seller_gmv)
               FROM metrics.kpi_seller_orders
               WHERE is_delivery_performance_eligible), 2)
            AS eligible_seller_gmv,
        ROUND((SELECT SUM(gmv)
               FROM metrics.kpi_orders
               WHERE is_delivery_performance_eligible), 2)
            AS eligible_order_gmv,
        ROUND((SELECT SUM(seller_late_gmv)
               FROM metrics.kpi_seller_orders), 2) AS late_seller_gmv,
        ROUND((SELECT SUM(late_gmv)
               FROM metrics.kpi_orders), 2) AS late_order_gmv
)
SELECT
    item_gmv = seller_gmv AS seller_matches_items,
    item_gmv = order_gmv AS items_match_orders,
    eligible_seller_gmv = eligible_order_gmv AS eligible_gmv_matches,
    late_seller_gmv = late_order_gmv AS late_gmv_matches
FROM totals;


-- Seller late contribution uses seller-order units.
SELECT
    SUM(late_seller_orders) = 6547 AS late_units_match,
    ROUND(SUM(seller_late_contribution), 10) = 1
        AS contribution_sums_to_one
FROM metrics.kpi_sellers;


-- Monthly totals reconcile to the full extract.
SELECT
    SUM(all_orders) = (SELECT all_orders FROM metrics.kpi_marketplace)
        AS orders_reconcile,
    SUM(late_count) = (SELECT late_count FROM metrics.kpi_marketplace)
        AS late_orders_reconcile
FROM metrics.kpi_marketplace_month;


-- Review populations partition all orders.
SELECT
    reviewed_orders
        + review_unusable_only_orders
        + no_review_orders = all_orders
        AS review_populations_reconcile,
    negative_review_count <= reviewed_orders
        AS negative_reviews_within_reviewed
FROM metrics.kpi_marketplace;
