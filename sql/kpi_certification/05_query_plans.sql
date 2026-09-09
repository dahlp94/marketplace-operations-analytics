-- Representative query plans. Diagnostic only.

\echo ===== 1. Marketplace delivery aggregation =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT
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
    ) AS late_count,
    ROUND(SUM(merchandise_value), 2) AS gmv
FROM analytics.fact_orders;


\echo ===== 2. Seller-order aggregation =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    seller_id,
    order_id,
    SUM(price) AS seller_gmv
FROM analytics.fact_order_items
GROUP BY seller_id, order_id;


\echo ===== 3. Marketplace rolling window =====
EXPLAIN (ANALYZE, BUFFERS)
WITH daily AS (
    SELECT
        purchase_date,
        COUNT(*) FILTER (WHERE is_late) AS late_count,
        COUNT(*) FILTER (
            WHERE is_delivery_performance_eligible
        ) AS eligible_count
    FROM metrics.kpi_orders
    GROUP BY purchase_date
)
SELECT
    purchase_date,
    SUM(late_count) OVER (
        ORDER BY purchase_date
        RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW
    ) AS late_30d,
    SUM(eligible_count) OVER (
        ORDER BY purchase_date
        RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW
    ) AS eligible_90d
FROM daily;


\echo ===== 4. Seller rolling window =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    seller_id,
    purchase_date,
    SUM(late_seller_orders) OVER (
        PARTITION BY seller_id
        ORDER BY purchase_date
        RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW
    ) AS late_30d
FROM (
    SELECT
        seller_id,
        purchase_date,
        COUNT(*) FILTER (WHERE is_late) AS late_seller_orders
    FROM metrics.kpi_seller_orders
    GROUP BY seller_id, purchase_date
) daily;


\echo ===== 5. Category join =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    i.seller_id,
    i.order_id,
    p.product_category,
    SUM(i.price) AS category_gmv
FROM analytics.fact_order_items i
JOIN analytics.dim_product p USING (product_id)
GROUP BY i.seller_id, i.order_id, p.product_category;


\echo ===== 6. Contribution ranking =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    seller_id,
    late_seller_orders,
    ROW_NUMBER() OVER (
        ORDER BY late_seller_orders DESC,
                 seller_late_gmv DESC NULLS LAST,
                 seller_id
    ) AS contribution_row_number,
    SUM(late_seller_orders) OVER (
        ORDER BY late_seller_orders DESC,
                 seller_late_gmv DESC NULLS LAST,
                 seller_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_late_seller_orders
FROM metrics.kpi_sellers;
