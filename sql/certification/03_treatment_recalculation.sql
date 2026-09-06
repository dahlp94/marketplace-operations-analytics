-- Independently recalculate material treatment counts from raw source data.

SELECT
    treatment,
    raw_recalculation,
    analytical_result,
    raw_recalculation = analytical_result AS matches
FROM (
    SELECT
        'eligible_on_time_delivery' AS treatment,
        (
            SELECT COUNT(*)
            FROM raw.orders
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
        ) AS raw_recalculation,
        (
            SELECT COUNT(*)
            FROM analytics.fact_orders
            WHERE eligible_on_time_delivery
        ) AS analytical_result

    UNION ALL

    SELECT
        'eligible_purchase_to_delivery',
        (
            SELECT COUNT(*)
            FROM raw.orders
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_delivered_customer_date >= order_purchase_timestamp
        ),
        (
            SELECT COUNT(*)
            FROM analytics.fact_orders
            WHERE eligible_purchase_to_delivery
        )

    UNION ALL

    SELECT
        'eligible_seller_handling',
        (
            SELECT COUNT(*)
            FROM raw.orders
            WHERE order_status = 'delivered'
              AND order_approved_at IS NOT NULL
              AND order_delivered_carrier_date IS NOT NULL
              AND order_approved_at >= order_purchase_timestamp
              AND order_delivered_carrier_date >= order_approved_at
        ),
        (
            SELECT COUNT(*)
            FROM analytics.fact_orders
            WHERE eligible_seller_handling
        )

    UNION ALL

    SELECT
        'eligible_carrier_transit',
        (
            SELECT COUNT(*)
            FROM raw.orders
            WHERE order_status = 'delivered'
              AND order_delivered_carrier_date IS NOT NULL
              AND order_delivered_customer_date IS NOT NULL
              AND order_delivered_carrier_date >= order_purchase_timestamp
              AND order_delivered_customer_date >= order_delivered_carrier_date
        ),
        (
            SELECT COUNT(*)
            FROM analytics.fact_orders
            WHERE eligible_carrier_transit
        )

    UNION ALL

    SELECT
        'reused_review_rows',
        (
            SELECT COUNT(*)
            FROM raw.order_reviews
            WHERE review_id IN (
                SELECT review_id
                FROM raw.order_reviews
                GROUP BY review_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT COUNT(*)
            FROM analytics.fact_reviews
            WHERE review_id_reused
        )

    UNION ALL

    SELECT
        'unknown_category_products',
        (
            SELECT COUNT(*)
            FROM raw.products
            WHERE product_category_name IS NULL
        ),
        (
            SELECT COUNT(*)
            FROM analytics.dim_product
            WHERE category_assignment = 'unknown'
        )

    UNION ALL

    SELECT
        'portuguese_fallback_products',
        (
            SELECT COUNT(*)
            FROM raw.products p
            LEFT JOIN raw.product_category_translation t
                ON t.product_category_name = p.product_category_name
            WHERE p.product_category_name IS NOT NULL
              AND t.product_category_name IS NULL
        ),
        (
            SELECT COUNT(*)
            FROM analytics.dim_product
            WHERE category_assignment = 'portuguese_fallback'
        )

    UNION ALL

    SELECT
        'unmatched_customer_geography',
        (
            SELECT COUNT(*)
            FROM raw.customers c
            LEFT JOIN (
                SELECT DISTINCT geolocation_zip_code_prefix
                FROM raw.geolocation
            ) g
                ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
            WHERE g.geolocation_zip_code_prefix IS NULL
        ),
        (
            SELECT COUNT(*)
            FROM analytics.dim_customer c
            JOIN analytics.dim_geography g
                ON g.zip_code_prefix = c.zip_code_prefix
            WHERE g.geo_unmatched
        )

    UNION ALL

    SELECT
        'unmatched_seller_geography',
        (
            SELECT COUNT(*)
            FROM raw.sellers s
            LEFT JOIN (
                SELECT DISTINCT geolocation_zip_code_prefix
                FROM raw.geolocation
            ) g
                ON g.geolocation_zip_code_prefix = s.seller_zip_code_prefix
            WHERE g.geolocation_zip_code_prefix IS NULL
        ),
        (
            SELECT COUNT(*)
            FROM analytics.dim_seller s
            JOIN analytics.dim_geography g
                ON g.zip_code_prefix = s.zip_code_prefix
            WHERE g.geo_unmatched
        )
) x
ORDER BY treatment;


-- Comparable full-month trend coverage is an analysis rule, not a model flag.

SELECT
    (
        SELECT COUNT(*)
        FROM raw.orders
        WHERE order_purchase_timestamp >= TIMESTAMP '2017-02-01'
          AND order_purchase_timestamp < TIMESTAMP '2018-09-01'
    ) AS raw_orders,

    (
        SELECT COUNT(*)
        FROM analytics.fact_orders
        WHERE purchase_date >= DATE '2017-02-01'
          AND purchase_date < DATE '2018-09-01'
    ) AS analytical_orders;
