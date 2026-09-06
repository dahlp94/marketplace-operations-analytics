-- Reconcile analytical tables to raw source coverage.

SELECT
    'orders' AS table_name,
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
    (SELECT COUNT(*) FROM analytics.dim_product);


-- Confirm approved order-level treatment counts.

SELECT
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE eligible_on_time_delivery
    ) AS eligible_on_time_delivery,

    COUNT(*) FILTER (
        WHERE eligible_purchase_to_delivery
    ) AS eligible_purchase_to_delivery,

    COUNT(*) FILTER (
        WHERE eligible_seller_handling
    ) AS eligible_seller_handling,

    COUNT(*) FILTER (
        WHERE eligible_carrier_transit
    ) AS eligible_carrier_transit,

    COUNT(*) FILTER (
        WHERE purchase_date >= DATE '2017-02-01'
          AND purchase_date < DATE '2018-09-01'
    ) AS full_month_trend_window_orders,

    COUNT(*) FILTER (
        WHERE monetary_diff_gt_tolerance
    ) AS monetary_diff_gt_tolerance,

    COUNT(*) FILTER (
        WHERE n_items = 0
    ) AS orders_without_items,

    COUNT(*) FILTER (
        WHERE n_payment_rows = 0
    ) AS orders_without_payments
FROM analytics.fact_orders;


-- Confirm product-category fallback treatment.

SELECT
    COUNT(*) FILTER (
        WHERE category_assignment = 'unknown'
    ) AS unknown_category_products,

    COUNT(*) FILTER (
        WHERE category_assignment = 'portuguese_fallback'
    ) AS portuguese_fallback_products
FROM analytics.dim_product;


-- Confirm review-ID treatment.

SELECT
    COUNT(*) AS review_rows,

    COUNT(*) FILTER (
        WHERE review_id_reused
    ) AS reused_review_rows,

    COUNT(*) FILTER (
        WHERE NOT review_id_reused
    ) AS usable_review_rows,

    COUNT(DISTINCT order_id) FILTER (
        WHERE review_id_reused
    ) AS orders_affected_by_reused_review_ids
FROM analytics.fact_reviews;