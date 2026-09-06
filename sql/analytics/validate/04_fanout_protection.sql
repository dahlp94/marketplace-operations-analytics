-- Joining child facts to one-row-per-order fact_orders
-- must preserve child row counts.

SELECT
    'fact_order_items -> fact_orders' AS join_name,
    (SELECT COUNT(*)
     FROM analytics.fact_order_items) AS native_rows,
    (
        SELECT COUNT(*)
        FROM analytics.fact_order_items i
        JOIN analytics.fact_orders o
            ON o.order_id = i.order_id
    ) AS joined_rows

UNION ALL

SELECT
    'fact_payments -> fact_orders',
    (SELECT COUNT(*)
     FROM analytics.fact_payments),
    (
        SELECT COUNT(*)
        FROM analytics.fact_payments p
        JOIN analytics.fact_orders o
            ON o.order_id = p.order_id
    )

UNION ALL

SELECT
    'fact_reviews -> fact_orders',
    (SELECT COUNT(*)
     FROM analytics.fact_reviews),
    (
        SELECT COUNT(*)
        FROM analytics.fact_reviews r
        JOIN analytics.fact_orders o
            ON o.order_id = r.order_id
    )

UNION ALL

SELECT
    'fact_orders -> dim_customer',
    (SELECT COUNT(*)
     FROM analytics.fact_orders),
    (
        SELECT COUNT(*)
        FROM analytics.fact_orders f
        JOIN analytics.dim_customer c
            ON c.customer_id = f.customer_id
    );


-- Order-level rollups must reconcile to their native child facts.

SELECT
    (
        SELECT ROUND(SUM(price), 2)
        FROM analytics.fact_order_items
    ) AS merchandise_native,

    (
        SELECT ROUND(SUM(merchandise_value), 2)
        FROM analytics.fact_orders
    ) AS merchandise_order_rollup,

    (
        SELECT ROUND(SUM(item_side_value), 2)
        FROM analytics.fact_order_items
    ) AS item_side_native,

    (
        SELECT ROUND(SUM(item_side_value), 2)
        FROM analytics.fact_orders
    ) AS item_side_order_rollup,

    (
        SELECT ROUND(SUM(payment_value), 2)
        FROM analytics.fact_payments
    ) AS payment_native,

    (
        SELECT ROUND(SUM(collected_payment), 2)
        FROM analytics.fact_orders
    ) AS payment_order_rollup;