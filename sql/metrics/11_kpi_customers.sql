-- Customer-level repeat-order summary.
-- Grain: one row per customer_unique_id.

DROP TABLE IF EXISTS metrics.kpi_customers;

CREATE TABLE metrics.kpi_customers AS
SELECT
    customer_unique_id,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (WHERE is_repeat_order) AS n_repeat_orders,
    COUNT(*) FILTER (WHERE is_delivered) AS n_delivered_orders,
    MIN(purchase_date) AS first_purchase_date,
    MAX(purchase_date) AS last_purchase_date,
    MIN(order_id) FILTER (WHERE customer_order_sequence = 1) AS first_order_id,
    BOOL_OR(is_repeat_order) AS is_repeat_customer
FROM metrics.kpi_orders
GROUP BY customer_unique_id;
