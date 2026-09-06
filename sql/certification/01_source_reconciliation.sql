-- Independent reconciliation from raw source tables to the analytical model.

SELECT
    entity,
    raw_rows,
    analytical_rows,
    raw_rows = analytical_rows AS reconciles
FROM (
    SELECT
        'orders' AS entity,
        (SELECT COUNT(*) FROM raw.orders) AS raw_rows,
        (SELECT COUNT(*) FROM analytics.fact_orders) AS analytical_rows

    UNION ALL

    SELECT
        'order_items',
        (SELECT COUNT(*) FROM raw.order_items),
        (SELECT COUNT(*) FROM analytics.fact_order_items)

    UNION ALL

    SELECT
        'order_payments',
        (SELECT COUNT(*) FROM raw.order_payments),
        (SELECT COUNT(*) FROM analytics.fact_payments)

    UNION ALL

    SELECT
        'order_reviews',
        (SELECT COUNT(*) FROM raw.order_reviews),
        (SELECT COUNT(*) FROM analytics.fact_reviews)

    UNION ALL

    SELECT
        'customers',
        (SELECT COUNT(*) FROM raw.customers),
        (SELECT COUNT(*) FROM analytics.dim_customer)

    UNION ALL

    SELECT
        'sellers',
        (SELECT COUNT(*) FROM raw.sellers),
        (SELECT COUNT(*) FROM analytics.dim_seller)

    UNION ALL

    SELECT
        'products',
        (SELECT COUNT(*) FROM raw.products),
        (SELECT COUNT(*) FROM analytics.dim_product)
) x
ORDER BY entity;


-- Source order statuses must be preserved.

SELECT
    COALESCE(r.order_status, a.order_status) AS order_status,
    COALESCE(r.n_orders, 0) AS raw_orders,
    COALESCE(a.n_orders, 0) AS analytical_orders,
    COALESCE(r.n_orders, 0) = COALESCE(a.n_orders, 0) AS reconciles
FROM (
    SELECT order_status, COUNT(*) AS n_orders
    FROM raw.orders
    GROUP BY order_status
) r
FULL OUTER JOIN (
    SELECT order_status, COUNT(*) AS n_orders
    FROM analytics.fact_orders
    GROUP BY order_status
) a
    ON a.order_status = r.order_status
ORDER BY order_status;
