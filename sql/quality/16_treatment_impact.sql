-- Quantify the size of candidate data-quality treatments.
-- These queries do not modify or delete source rows.

-- Metric-specific eligibility for delivered orders.
SELECT
    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
    ) AS usable_for_on_time_delivery,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_delivered_customer_date >= order_purchase_timestamp
    ) AS usable_for_purchase_to_delivery,

    COUNT(*) FILTER (
        WHERE order_approved_at IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_approved_at >= order_purchase_timestamp
          AND order_delivered_carrier_date >= order_approved_at
    ) AS usable_for_seller_handling,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date IS NOT NULL
          AND order_delivered_carrier_date >= order_purchase_timestamp
          AND order_delivered_customer_date >= order_delivered_carrier_date
    ) AS usable_for_carrier_transit

FROM raw.orders
WHERE order_status = 'delivered';

-- Marketplace exposure affected by missing or untranslated categories.
SELECT
    COUNT(i.order_item_id) FILTER (
        WHERE p.product_category_name IS NULL
           OR t.product_category_name IS NULL
    ) AS affected_item_rows,
    COUNT(DISTINCT i.order_id) FILTER (
        WHERE p.product_category_name IS NULL
           OR t.product_category_name IS NULL
    ) AS affected_orders,
    ROUND(
        SUM(i.price + i.freight_value) FILTER (
            WHERE p.product_category_name IS NULL
               OR t.product_category_name IS NULL
        ),
        2
    ) AS affected_item_side_value,
    ROUND(SUM(i.price + i.freight_value), 2) AS total_item_side_value
FROM raw.order_items i
JOIN raw.products p
    ON p.product_id = i.product_id
LEFT JOIN raw.product_category_translation t
    ON t.product_category_name = p.product_category_name;

-- Review rows affected by reused review IDs.
WITH reused AS (
    SELECT review_id
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS review_rows,
    COUNT(*) FILTER (WHERE x.review_id IS NOT NULL) AS rows_with_reused_review_id,
    COUNT(DISTINCT r.order_id) FILTER (WHERE x.review_id IS NOT NULL) AS orders_affected
FROM raw.order_reviews r
LEFT JOIN reused x
    ON x.review_id = r.review_id;
