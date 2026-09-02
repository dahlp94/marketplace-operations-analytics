-- Trace representative orders across the raw source tables.

-- 1) Simple delivered order: 1 item, 1 payment, 1 review.
WITH simple AS (
    SELECT o.order_id
    FROM raw.orders o
    JOIN (
        SELECT order_id
        FROM raw.order_items
        GROUP BY order_id
        HAVING COUNT(*) = 1
    ) i ON i.order_id = o.order_id
    JOIN (
        SELECT order_id
        FROM raw.order_payments
        GROUP BY order_id
        HAVING COUNT(*) = 1
    ) p ON p.order_id = o.order_id
    JOIN (
        SELECT order_id
        FROM raw.order_reviews
        GROUP BY order_id
        HAVING COUNT(*) = 1
    ) r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    ORDER BY o.order_purchase_timestamp, o.order_id
    LIMIT 1
)
SELECT
    'simple_1_1_1' AS case_name,
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    i.price,
    i.freight_value,
    p.payment_sequential,
    p.payment_type,
    p.payment_value,
    r.review_id,
    r.review_score,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state
FROM simple s
JOIN raw.orders o
    ON o.order_id = s.order_id
JOIN raw.order_items i
    ON i.order_id = s.order_id
JOIN raw.order_payments p
    ON p.order_id = s.order_id
JOIN raw.order_reviews r
    ON r.order_id = s.order_id
JOIN raw.customers c
    ON c.customer_id = o.customer_id;

-- 2) Multi-item, single-payment order.
WITH chosen AS (
    SELECT o.order_id
    FROM raw.orders o
    JOIN (
        SELECT order_id
        FROM raw.order_items
        GROUP BY order_id
        HAVING COUNT(*) >= 3
    ) i ON i.order_id = o.order_id
    JOIN (
        SELECT order_id
        FROM raw.order_payments
        GROUP BY order_id
        HAVING COUNT(*) = 1
    ) p ON p.order_id = o.order_id
    ORDER BY o.order_id
    LIMIT 1
)
SELECT
    'multi_item_single_payment' AS case_name,
    o.order_id,
    o.order_status,
    i.order_item_id,
    i.seller_id,
    i.price,
    p.payment_sequential,
    p.payment_value
FROM chosen c
JOIN raw.orders o
    ON o.order_id = c.order_id
JOIN raw.order_items i
    ON i.order_id = c.order_id
JOIN raw.order_payments p
    ON p.order_id = c.order_id
ORDER BY i.order_item_id;

-- 3) Single-item, multi-payment order.
WITH chosen AS (
    SELECT o.order_id
    FROM raw.orders o
    JOIN (
        SELECT order_id
        FROM raw.order_items
        GROUP BY order_id
        HAVING COUNT(*) = 1
    ) i ON i.order_id = o.order_id
    JOIN (
        SELECT order_id
        FROM raw.order_payments
        GROUP BY order_id
        HAVING COUNT(*) >= 3
    ) p ON p.order_id = o.order_id
    ORDER BY o.order_id
    LIMIT 1
)
SELECT
    'single_item_multi_payment' AS case_name,
    o.order_id,
    o.order_status,
    i.order_item_id,
    i.price,
    i.freight_value,
    p.payment_sequential,
    p.payment_type,
    p.payment_value
FROM chosen c
JOIN raw.orders o
    ON o.order_id = c.order_id
JOIN raw.order_items i
    ON i.order_id = c.order_id
JOIN raw.order_payments p
    ON p.order_id = c.order_id
ORDER BY p.payment_sequential;

-- 4) Multi-seller order.
WITH chosen AS (
    SELECT order_id
    FROM raw.order_items
    GROUP BY order_id
    HAVING COUNT(DISTINCT seller_id) >= 2
    ORDER BY order_id
    LIMIT 1
)
SELECT
    'multi_seller_order' AS case_name,
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    i.price,
    i.freight_value
FROM raw.order_items i
JOIN chosen c
    ON c.order_id = i.order_id
ORDER BY i.order_item_id;

-- 5) Orders with no items, if any.
SELECT
    'order_without_items' AS case_name,
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp
FROM raw.orders o
LEFT JOIN raw.order_items i
    ON i.order_id = o.order_id
WHERE i.order_id IS NULL
ORDER BY o.order_status, o.order_id
LIMIT 5;

-- 6) Orders with no payments, if any.
SELECT
    'order_without_payments' AS case_name,
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp
FROM raw.orders o
LEFT JOIN raw.order_payments p
    ON p.order_id = o.order_id
WHERE p.order_id IS NULL
ORDER BY o.order_status, o.order_id
LIMIT 5;

-- 7) Orders with no reviews, if any.
SELECT
    'order_without_reviews' AS case_name,
    o.order_id,
    o.order_status
FROM raw.orders o
LEFT JOIN raw.order_reviews r
    ON r.order_id = o.order_id
WHERE r.order_id IS NULL
ORDER BY o.order_id
LIMIT 5;

-- 8) One duplicated review_id, if any.
SELECT
    'duplicate_review_id' AS case_name,
    review_id,
    order_id,
    review_score,
    review_creation_date
FROM raw.order_reviews
WHERE review_id IN (
    SELECT review_id
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC, review_id
    LIMIT 1
)
ORDER BY order_id;
