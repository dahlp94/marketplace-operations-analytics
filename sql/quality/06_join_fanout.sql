-- Demonstrate how joining order_items and order_payments on order_id can duplicate measures.

-- How common is the fan-out risk?
WITH item_counts AS (
    SELECT order_id, COUNT(*) AS n_items
    FROM raw.order_items
    GROUP BY order_id
),
payment_counts AS (
    SELECT order_id, COUNT(*) AS n_payments
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders_multi_item_and_multi_payment,
    SUM(i.n_items) AS item_rows,
    SUM(p.n_payments) AS payment_rows,
    SUM(i.n_items * p.n_payments) AS rows_after_naive_join
FROM item_counts i
JOIN payment_counts p
    ON p.order_id = i.order_id
WHERE i.n_items >= 2
  AND p.n_payments >= 2;

-- One real worked example.
WITH item_stats AS (
    SELECT
        order_id,
        COUNT(*) AS n_items,
        SUM(price + freight_value) AS true_item_value
    FROM raw.order_items
    GROUP BY order_id
),
payment_stats AS (
    SELECT
        order_id,
        COUNT(*) AS n_payments,
        SUM(payment_value) AS true_payment_value
    FROM raw.order_payments
    GROUP BY order_id
),
chosen AS (
    SELECT i.order_id
    FROM item_stats i
    JOIN payment_stats p
        ON p.order_id = i.order_id
    WHERE i.n_items >= 2
      AND p.n_payments >= 2
    ORDER BY i.n_items DESC, p.n_payments DESC, i.order_id
    LIMIT 1
),
naive AS (
    SELECT
        i.order_id,
        COUNT(*) AS naive_rows,
        SUM(i.price + i.freight_value) AS naive_item_value,
        SUM(p.payment_value) AS naive_payment_value
    FROM raw.order_items i
    JOIN raw.order_payments p
        ON p.order_id = i.order_id
    JOIN chosen c
        ON c.order_id = i.order_id
    GROUP BY i.order_id
)
SELECT
    c.order_id,
    i.n_items,
    p.n_payments,
    i.n_items * p.n_payments AS expected_naive_rows,
    n.naive_rows,
    i.true_item_value,
    n.naive_item_value,
    n.naive_item_value / NULLIF(i.true_item_value, 0) AS item_duplication_factor,
    p.true_payment_value,
    n.naive_payment_value,
    n.naive_payment_value / NULLIF(p.true_payment_value, 0) AS payment_duplication_factor
FROM chosen c
JOIN item_stats i
    ON i.order_id = c.order_id
JOIN payment_stats p
    ON p.order_id = c.order_id
JOIN naive n
    ON n.order_id = c.order_id;

-- Marketplace-wide effect among orders that have both items and payments.
WITH item_stats AS (
    SELECT
        order_id,
        COUNT(*) AS n_items,
        SUM(price + freight_value) AS true_item_value
    FROM raw.order_items
    GROUP BY order_id
),
payment_stats AS (
    SELECT
        order_id,
        COUNT(*) AS n_payments,
        SUM(payment_value) AS true_payment_value
    FROM raw.order_payments
    GROUP BY order_id
),
shared_orders AS (
    SELECT
        i.order_id,
        i.n_items,
        p.n_payments,
        i.true_item_value,
        p.true_payment_value
    FROM item_stats i
    JOIN payment_stats p
        ON p.order_id = i.order_id
),
naive AS (
    SELECT
        i.order_id,
        COUNT(*) AS naive_rows,
        SUM(i.price + i.freight_value) AS naive_item_value,
        SUM(p.payment_value) AS naive_payment_value
    FROM raw.order_items i
    JOIN raw.order_payments p
        ON p.order_id = i.order_id
    GROUP BY i.order_id
)
SELECT
    COUNT(*) AS orders_with_items_and_payments,
    SUM(s.n_items) AS item_rows_before_join,
    SUM(s.n_payments) AS payment_rows_before_join,
    SUM(n.naive_rows) AS rows_after_naive_join,
    SUM(s.true_item_value) AS true_item_value,
    SUM(n.naive_item_value) AS naive_item_value,
    SUM(s.true_payment_value) AS true_payment_value,
    SUM(n.naive_payment_value) AS naive_payment_value
FROM shared_orders s
JOIN naive n
    ON n.order_id = s.order_id;
