-- Establish the meaning of customer_id versus customer_unique_id.

SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT customer_id) AS distinct_customer_id,
    COUNT(DISTINCT customer_unique_id) AS distinct_customer_unique_id,
    COUNT(*) - COUNT(DISTINCT customer_unique_id) AS extra_rows_beyond_unique_buyers
FROM raw.customers;

-- Count actual orders per underlying buyer.
WITH buyer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS n_orders
    FROM raw.customers c
    JOIN raw.orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS unique_buyers,
    COUNT(*) FILTER (WHERE n_orders = 1) AS buyers_with_1_order,
    COUNT(*) FILTER (WHERE n_orders = 2) AS buyers_with_2_orders,
    COUNT(*) FILTER (WHERE n_orders >= 3) AS buyers_with_3plus_orders,
    MAX(n_orders) AS max_orders_per_buyer
FROM buyer_order_counts;

-- One buyer with multiple order-specific customer_ids.
WITH repeat_buyer AS (
    SELECT c.customer_unique_id
    FROM raw.customers c
    JOIN raw.orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
    HAVING COUNT(o.order_id) >= 2
    ORDER BY COUNT(o.order_id) DESC, c.customer_unique_id
    LIMIT 1
)
SELECT
    c.customer_unique_id,
    c.customer_id,
    o.order_id,
    o.order_purchase_timestamp,
    c.customer_city,
    c.customer_state
FROM raw.customers c
JOIN raw.orders o
    ON o.customer_id = c.customer_id
JOIN repeat_buyer b
    ON b.customer_unique_id = c.customer_unique_id
ORDER BY o.order_purchase_timestamp;
