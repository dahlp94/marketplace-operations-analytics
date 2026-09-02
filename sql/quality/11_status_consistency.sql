-- Check whether order status agrees with lifecycle fields and child records.

-- Timestamp presence by order status.
SELECT
    order_status,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NOT NULL) AS has_approved,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NOT NULL) AS has_carrier,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL) AS has_customer_delivery
FROM raw.orders
GROUP BY order_status
ORDER BY n_orders DESC;

-- Suspicious status/timestamp combinations.
SELECT
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
    ) AS delivered_missing_customer_delivery,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_carrier_date IS NULL
    ) AS delivered_missing_carrier,
    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
          AND order_delivered_customer_date IS NOT NULL
    ) AS canceled_with_customer_delivery,
    COUNT(*) FILTER (
        WHERE order_status = 'shipped'
          AND order_delivered_customer_date IS NOT NULL
    ) AS shipped_with_customer_delivery
FROM raw.orders;

-- Missing item/payment children by status.
SELECT
    o.order_status,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (WHERE i.order_id IS NULL) AS orders_without_items,
    COUNT(*) FILTER (WHERE p.order_id IS NULL) AS orders_without_payments
FROM raw.orders o
LEFT JOIN (
    SELECT DISTINCT order_id
    FROM raw.order_items
) i ON i.order_id = o.order_id
LEFT JOIN (
    SELECT DISTINCT order_id
    FROM raw.order_payments
) p ON p.order_id = o.order_id
GROUP BY o.order_status
ORDER BY n_orders DESC;
