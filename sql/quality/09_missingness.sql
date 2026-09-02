-- Investigate missing values that can affect operational analysis.

-- Order lifecycle timestamps by status.
SELECT
    order_status,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS missing_approved,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS missing_carrier,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_customer_delivery
FROM raw.orders
GROUP BY order_status
ORDER BY n_orders DESC;

-- Missing lifecycle timestamps among delivered orders.
SELECT
    COUNT(*) AS delivered_orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS missing_approved,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS missing_carrier,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_customer_delivery,
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
           OR order_delivered_carrier_date IS NULL
           OR order_delivered_customer_date IS NULL
    ) AS missing_any_lifecycle_timestamp
FROM raw.orders
WHERE order_status = 'delivered';

-- Product fields that may affect category and shipping analysis.
SELECT
    COUNT(*) AS products,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS missing_category,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS missing_weight,
    COUNT(*) FILTER (
        WHERE product_length_cm IS NULL
           OR product_height_cm IS NULL
           OR product_width_cm IS NULL
    ) AS missing_any_dimension
FROM raw.products;
