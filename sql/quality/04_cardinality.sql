-- Parent/child multiplicity for the main source relationships.

-- orders -> order_items
WITH counts AS (
    SELECT o.order_id, COUNT(i.order_id) AS n_children
    FROM raw.orders o
    LEFT JOIN raw.order_items i
        ON i.order_id = o.order_id
    GROUP BY o.order_id
)
SELECT
    'orders -> order_items' AS relationship,
    COUNT(*) AS n_parents,
    COUNT(*) FILTER (WHERE n_children = 0) AS parents_with_0,
    COUNT(*) FILTER (WHERE n_children = 1) AS parents_with_1,
    COUNT(*) FILTER (WHERE n_children >= 2) AS parents_with_2plus,
    MAX(n_children) AS max_children,
    SUM(n_children) AS child_rows
FROM counts;

-- orders -> order_payments
WITH counts AS (
    SELECT o.order_id, COUNT(p.order_id) AS n_children
    FROM raw.orders o
    LEFT JOIN raw.order_payments p
        ON p.order_id = o.order_id
    GROUP BY o.order_id
)
SELECT
    'orders -> order_payments' AS relationship,
    COUNT(*) AS n_parents,
    COUNT(*) FILTER (WHERE n_children = 0) AS parents_with_0,
    COUNT(*) FILTER (WHERE n_children = 1) AS parents_with_1,
    COUNT(*) FILTER (WHERE n_children >= 2) AS parents_with_2plus,
    MAX(n_children) AS max_children,
    SUM(n_children) AS child_rows
FROM counts;

-- orders -> order_reviews
WITH counts AS (
    SELECT o.order_id, COUNT(r.order_id) AS n_children
    FROM raw.orders o
    LEFT JOIN raw.order_reviews r
        ON r.order_id = o.order_id
    GROUP BY o.order_id
)
SELECT
    'orders -> order_reviews' AS relationship,
    COUNT(*) AS n_parents,
    COUNT(*) FILTER (WHERE n_children = 0) AS parents_with_0,
    COUNT(*) FILTER (WHERE n_children = 1) AS parents_with_1,
    COUNT(*) FILTER (WHERE n_children >= 2) AS parents_with_2plus,
    MAX(n_children) AS max_children,
    SUM(n_children) AS child_rows
FROM counts;

-- customers.customer_id -> orders
WITH counts AS (
    SELECT c.customer_id, COUNT(o.order_id) AS n_children
    FROM raw.customers c
    LEFT JOIN raw.orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT
    'customers.customer_id -> orders' AS relationship,
    COUNT(*) AS n_parents,
    COUNT(*) FILTER (WHERE n_children = 0) AS parents_with_0,
    COUNT(*) FILTER (WHERE n_children = 1) AS parents_with_1,
    COUNT(*) FILTER (WHERE n_children >= 2) AS parents_with_2plus,
    MAX(n_children) AS max_children,
    SUM(n_children) AS child_rows
FROM counts;

-- sellers -> order_items
WITH counts AS (
    SELECT s.seller_id, COUNT(i.seller_id) AS n_children
    FROM raw.sellers s
    LEFT JOIN raw.order_items i
        ON i.seller_id = s.seller_id
    GROUP BY s.seller_id
)
SELECT
    'sellers -> order_items' AS relationship,
    COUNT(*) AS n_parents,
    COUNT(*) FILTER (WHERE n_children = 0) AS parents_with_0,
    COUNT(*) FILTER (WHERE n_children = 1) AS parents_with_1,
    COUNT(*) FILTER (WHERE n_children >= 2) AS parents_with_2plus,
    MAX(n_children) AS max_children,
    SUM(n_children) AS child_rows
FROM counts;

-- products -> order_items
WITH counts AS (
    SELECT p.product_id, COUNT(i.product_id) AS n_children
    FROM raw.products p
    LEFT JOIN raw.order_items i
        ON i.product_id = p.product_id
    GROUP BY p.product_id
)
SELECT
    'products -> order_items' AS relationship,
    COUNT(*) AS n_parents,
    COUNT(*) FILTER (WHERE n_children = 0) AS parents_with_0,
    COUNT(*) FILTER (WHERE n_children = 1) AS parents_with_1,
    COUNT(*) FILTER (WHERE n_children >= 2) AS parents_with_2plus,
    MAX(n_children) AS max_children,
    SUM(n_children) AS child_rows
FROM counts;

-- Sellers per order.
WITH sellers_per_order AS (
    SELECT order_id, COUNT(DISTINCT seller_id) AS n_sellers
    FROM raw.order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders_with_items,
    COUNT(*) FILTER (WHERE n_sellers = 1) AS single_seller_orders,
    COUNT(*) FILTER (WHERE n_sellers >= 2) AS multi_seller_orders,
    MAX(n_sellers) AS max_sellers_on_one_order
FROM sellers_per_order;

-- Geolocation rows per zip prefix.
SELECT
    (SELECT COUNT(*) FROM raw.geolocation) AS geo_rows,
    COUNT(*) AS distinct_zip_prefixes,
    MAX(n_rows) AS max_rows_per_zip
FROM (
    SELECT geolocation_zip_code_prefix, COUNT(*) AS n_rows
    FROM raw.geolocation
    GROUP BY geolocation_zip_code_prefix
) z;
