-- Anti-joins for fact-to-dimension and child-to-order coverage.

SELECT
    'fact_orders.customer_id → dim_customer' AS relationship,
    COUNT(*) FILTER (WHERE d.customer_id IS NULL) AS unmatched_rows
FROM analytics.fact_orders f
LEFT JOIN analytics.dim_customer d
    ON d.customer_id = f.customer_id

UNION ALL

SELECT
    'fact_orders.purchase_date → dim_date',
    COUNT(*) FILTER (WHERE d.date_day IS NULL)
FROM analytics.fact_orders f
LEFT JOIN analytics.dim_date d
    ON d.date_day = f.purchase_date

UNION ALL

SELECT
    'fact_order_items.order_id → fact_orders',
    COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM analytics.fact_order_items i
LEFT JOIN analytics.fact_orders o
    ON o.order_id = i.order_id

UNION ALL

SELECT
    'fact_order_items.product_id → dim_product',
    COUNT(*) FILTER (WHERE p.product_id IS NULL)
FROM analytics.fact_order_items i
LEFT JOIN analytics.dim_product p
    ON p.product_id = i.product_id

UNION ALL

SELECT
    'fact_order_items.seller_id → dim_seller',
    COUNT(*) FILTER (WHERE s.seller_id IS NULL)
FROM analytics.fact_order_items i
LEFT JOIN analytics.dim_seller s
    ON s.seller_id = i.seller_id

UNION ALL

SELECT
    'fact_payments.order_id → fact_orders',
    COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM analytics.fact_payments p
LEFT JOIN analytics.fact_orders o
    ON o.order_id = p.order_id

UNION ALL

SELECT
    'fact_reviews.order_id → fact_orders',
    COUNT(*) FILTER (WHERE o.order_id IS NULL)
FROM analytics.fact_reviews r
LEFT JOIN analytics.fact_orders o
    ON o.order_id = r.order_id

UNION ALL

SELECT
    'dim_customer.zip → dim_geography',
    COUNT(*) FILTER (WHERE g.zip_code_prefix IS NULL)
FROM analytics.dim_customer c
LEFT JOIN analytics.dim_geography g
    ON g.zip_code_prefix = c.zip_code_prefix

UNION ALL

SELECT
    'dim_seller.zip → dim_geography',
    COUNT(*) FILTER (WHERE g.zip_code_prefix IS NULL)
FROM analytics.dim_seller s
LEFT JOIN analytics.dim_geography g
    ON g.zip_code_prefix = s.zip_code_prefix
