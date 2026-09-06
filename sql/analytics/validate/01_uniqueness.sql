-- Hard uniqueness checks for documented grains.

SELECT
    'dim_date' AS table_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT date_day) AS n_keys,
    (COUNT(*) = COUNT(DISTINCT date_day)) AS is_unique
FROM analytics.dim_date

UNION ALL

SELECT
    'dim_geography',
    COUNT(*),
    COUNT(DISTINCT zip_code_prefix),
    (COUNT(*) = COUNT(DISTINCT zip_code_prefix))
FROM analytics.dim_geography

UNION ALL

SELECT
    'dim_customer',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    (COUNT(*) = COUNT(DISTINCT customer_id))
FROM analytics.dim_customer

UNION ALL

SELECT
    'dim_seller',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    (COUNT(*) = COUNT(DISTINCT seller_id))
FROM analytics.dim_seller

UNION ALL

SELECT
    'dim_product',
    COUNT(*),
    COUNT(DISTINCT product_id),
    (COUNT(*) = COUNT(DISTINCT product_id))
FROM analytics.dim_product

UNION ALL

SELECT
    'fact_orders',
    COUNT(*),
    COUNT(DISTINCT order_id),
    (COUNT(*) = COUNT(DISTINCT order_id))
FROM analytics.fact_orders

UNION ALL

SELECT
    'fact_order_items',
    COUNT(*),
    COUNT(DISTINCT (order_id, order_item_id)),
    (COUNT(*) = COUNT(DISTINCT (order_id, order_item_id)))
FROM analytics.fact_order_items

UNION ALL

SELECT
    'fact_payments',
    COUNT(*),
    COUNT(DISTINCT (order_id, payment_sequential)),
    (COUNT(*) = COUNT(DISTINCT (order_id, payment_sequential)))
FROM analytics.fact_payments

UNION ALL

SELECT
    'fact_reviews',
    COUNT(*),
    COUNT(DISTINCT (review_id, order_id)),
    (COUNT(*) = COUNT(DISTINCT (review_id, order_id)))
FROM analytics.fact_reviews;
