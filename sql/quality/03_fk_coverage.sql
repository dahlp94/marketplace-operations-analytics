-- Check whether non-null child keys match their expected parent tables.

SELECT
    'orders.customer_id -> customers.customer_id' AS relationship,
    COUNT(*) AS child_rows,
    COUNT(*) FILTER (
        WHERE o.customer_id IS NOT NULL
          AND c.customer_id IS NULL
    ) AS unmatched_child_rows,
    COUNT(DISTINCT o.customer_id) FILTER (
        WHERE o.customer_id IS NOT NULL
          AND c.customer_id IS NULL
    ) AS unmatched_child_keys
FROM raw.orders o
LEFT JOIN raw.customers c
    ON c.customer_id = o.customer_id

UNION ALL

SELECT
    'order_items.order_id -> orders.order_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE i.order_id IS NOT NULL
          AND o.order_id IS NULL
    ),
    COUNT(DISTINCT i.order_id) FILTER (
        WHERE i.order_id IS NOT NULL
          AND o.order_id IS NULL
    )
FROM raw.order_items i
LEFT JOIN raw.orders o
    ON o.order_id = i.order_id

UNION ALL

SELECT
    'order_payments.order_id -> orders.order_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE p.order_id IS NOT NULL
          AND o.order_id IS NULL
    ),
    COUNT(DISTINCT p.order_id) FILTER (
        WHERE p.order_id IS NOT NULL
          AND o.order_id IS NULL
    )
FROM raw.order_payments p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id

UNION ALL

SELECT
    'order_reviews.order_id -> orders.order_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE r.order_id IS NOT NULL
          AND o.order_id IS NULL
    ),
    COUNT(DISTINCT r.order_id) FILTER (
        WHERE r.order_id IS NOT NULL
          AND o.order_id IS NULL
    )
FROM raw.order_reviews r
LEFT JOIN raw.orders o
    ON o.order_id = r.order_id

UNION ALL

SELECT
    'order_items.seller_id -> sellers.seller_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE i.seller_id IS NOT NULL
          AND s.seller_id IS NULL
    ),
    COUNT(DISTINCT i.seller_id) FILTER (
        WHERE i.seller_id IS NOT NULL
          AND s.seller_id IS NULL
    )
FROM raw.order_items i
LEFT JOIN raw.sellers s
    ON s.seller_id = i.seller_id

UNION ALL

SELECT
    'order_items.product_id -> products.product_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE i.product_id IS NOT NULL
          AND p.product_id IS NULL
    ),
    COUNT(DISTINCT i.product_id) FILTER (
        WHERE i.product_id IS NOT NULL
          AND p.product_id IS NULL
    )
FROM raw.order_items i
LEFT JOIN raw.products p
    ON p.product_id = i.product_id

UNION ALL

SELECT
    'products.product_category_name -> translation',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE p.product_category_name IS NOT NULL
          AND t.product_category_name IS NULL
    ),
    COUNT(DISTINCT p.product_category_name) FILTER (
        WHERE p.product_category_name IS NOT NULL
          AND t.product_category_name IS NULL
    )
FROM raw.products p
LEFT JOIN raw.product_category_translation t
    ON t.product_category_name = p.product_category_name

ORDER BY relationship;
