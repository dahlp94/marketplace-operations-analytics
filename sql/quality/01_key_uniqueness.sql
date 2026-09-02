-- Test the candidate key for each raw source table.

SELECT
    'orders.order_id' AS candidate_key,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT order_id) AS n_distinct_key,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS n_null_key,
    COUNT(*) = COUNT(DISTINCT order_id)
        AND COUNT(*) FILTER (WHERE order_id IS NULL) = 0 AS is_unique
FROM raw.orders

UNION ALL

SELECT
    'order_items.(order_id, order_item_id)',
    COUNT(*),
    COUNT(DISTINCT (order_id, order_item_id)),
    COUNT(*) FILTER (WHERE order_id IS NULL OR order_item_id IS NULL),
    COUNT(*) = COUNT(DISTINCT (order_id, order_item_id))
        AND COUNT(*) FILTER (WHERE order_id IS NULL OR order_item_id IS NULL) = 0
FROM raw.order_items

UNION ALL

SELECT
    'order_payments.(order_id, payment_sequential)',
    COUNT(*),
    COUNT(DISTINCT (order_id, payment_sequential)),
    COUNT(*) FILTER (WHERE order_id IS NULL OR payment_sequential IS NULL),
    COUNT(*) = COUNT(DISTINCT (order_id, payment_sequential))
        AND COUNT(*) FILTER (WHERE order_id IS NULL OR payment_sequential IS NULL) = 0
FROM raw.order_payments

UNION ALL

SELECT
    'order_reviews.review_id',
    COUNT(*),
    COUNT(DISTINCT review_id),
    COUNT(*) FILTER (WHERE review_id IS NULL),
    COUNT(*) = COUNT(DISTINCT review_id)
        AND COUNT(*) FILTER (WHERE review_id IS NULL) = 0
FROM raw.order_reviews

UNION ALL

SELECT
    'order_reviews.(review_id, order_id)',
    COUNT(*),
    COUNT(DISTINCT (review_id, order_id)),
    COUNT(*) FILTER (WHERE review_id IS NULL OR order_id IS NULL),
    COUNT(*) = COUNT(DISTINCT (review_id, order_id))
        AND COUNT(*) FILTER (WHERE review_id IS NULL OR order_id IS NULL) = 0
FROM raw.order_reviews

UNION ALL

SELECT
    'customers.customer_id',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    COUNT(*) FILTER (WHERE customer_id IS NULL),
    COUNT(*) = COUNT(DISTINCT customer_id)
        AND COUNT(*) FILTER (WHERE customer_id IS NULL) = 0
FROM raw.customers

UNION ALL

SELECT
    'sellers.seller_id',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) FILTER (WHERE seller_id IS NULL),
    COUNT(*) = COUNT(DISTINCT seller_id)
        AND COUNT(*) FILTER (WHERE seller_id IS NULL) = 0
FROM raw.sellers

UNION ALL

SELECT
    'products.product_id',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) FILTER (WHERE product_id IS NULL),
    COUNT(*) = COUNT(DISTINCT product_id)
        AND COUNT(*) FILTER (WHERE product_id IS NULL) = 0
FROM raw.products

UNION ALL

SELECT
    'product_category_translation.product_category_name',
    COUNT(*),
    COUNT(DISTINCT product_category_name),
    COUNT(*) FILTER (WHERE product_category_name IS NULL),
    COUNT(*) = COUNT(DISTINCT product_category_name)
        AND COUNT(*) FILTER (WHERE product_category_name IS NULL) = 0
FROM raw.product_category_translation

ORDER BY candidate_key;
