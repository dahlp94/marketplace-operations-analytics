-- Null counts for fields important to grain, joins, timestamps, and money.

SELECT 'orders' AS table_name, 'order_id' AS column_name,
       COUNT(*) AS n_rows,
       COUNT(*) FILTER (WHERE order_id IS NULL) AS n_null,
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / COUNT(*), 4) AS pct_null
FROM raw.orders
UNION ALL
SELECT 'orders', 'customer_id', COUNT(*), COUNT(*) FILTER (WHERE customer_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE customer_id IS NULL) / COUNT(*), 4) FROM raw.orders
UNION ALL
SELECT 'orders', 'order_status', COUNT(*), COUNT(*) FILTER (WHERE order_status IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_status IS NULL) / COUNT(*), 4) FROM raw.orders
UNION ALL
SELECT 'orders', 'order_purchase_timestamp', COUNT(*), COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) / COUNT(*), 4) FROM raw.orders
UNION ALL
SELECT 'orders', 'order_approved_at', COUNT(*), COUNT(*) FILTER (WHERE order_approved_at IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_approved_at IS NULL) / COUNT(*), 4) FROM raw.orders
UNION ALL
SELECT 'orders', 'order_delivered_carrier_date', COUNT(*), COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) / COUNT(*), 4) FROM raw.orders
UNION ALL
SELECT 'orders', 'order_delivered_customer_date', COUNT(*), COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) / COUNT(*), 4) FROM raw.orders
UNION ALL
SELECT 'orders', 'order_estimated_delivery_date', COUNT(*), COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) / COUNT(*), 4) FROM raw.orders
UNION ALL
SELECT 'order_items', 'order_id', COUNT(*), COUNT(*) FILTER (WHERE order_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / COUNT(*), 4) FROM raw.order_items
UNION ALL
SELECT 'order_items', 'product_id', COUNT(*), COUNT(*) FILTER (WHERE product_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE product_id IS NULL) / COUNT(*), 4) FROM raw.order_items
UNION ALL
SELECT 'order_items', 'seller_id', COUNT(*), COUNT(*) FILTER (WHERE seller_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE seller_id IS NULL) / COUNT(*), 4) FROM raw.order_items
UNION ALL
SELECT 'order_items', 'price', COUNT(*), COUNT(*) FILTER (WHERE price IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE price IS NULL) / COUNT(*), 4) FROM raw.order_items
UNION ALL
SELECT 'order_items', 'freight_value', COUNT(*), COUNT(*) FILTER (WHERE freight_value IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE freight_value IS NULL) / COUNT(*), 4) FROM raw.order_items
UNION ALL
SELECT 'order_payments', 'order_id', COUNT(*), COUNT(*) FILTER (WHERE order_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / COUNT(*), 4) FROM raw.order_payments
UNION ALL
SELECT 'order_payments', 'payment_value', COUNT(*), COUNT(*) FILTER (WHERE payment_value IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE payment_value IS NULL) / COUNT(*), 4) FROM raw.order_payments
UNION ALL
SELECT 'order_reviews', 'review_id', COUNT(*), COUNT(*) FILTER (WHERE review_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_id IS NULL) / COUNT(*), 4) FROM raw.order_reviews
UNION ALL
SELECT 'order_reviews', 'order_id', COUNT(*), COUNT(*) FILTER (WHERE order_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_id IS NULL) / COUNT(*), 4) FROM raw.order_reviews
UNION ALL
SELECT 'order_reviews', 'review_score', COUNT(*), COUNT(*) FILTER (WHERE review_score IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score IS NULL) / COUNT(*), 4) FROM raw.order_reviews
UNION ALL
SELECT 'customers', 'customer_unique_id', COUNT(*), COUNT(*) FILTER (WHERE customer_unique_id IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE customer_unique_id IS NULL) / COUNT(*), 4) FROM raw.customers
UNION ALL
SELECT 'customers', 'customer_zip_code_prefix', COUNT(*), COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) / COUNT(*), 4) FROM raw.customers
UNION ALL
SELECT 'sellers', 'seller_zip_code_prefix', COUNT(*), COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) / COUNT(*), 4) FROM raw.sellers
UNION ALL
SELECT 'products', 'product_category_name', COUNT(*), COUNT(*) FILTER (WHERE product_category_name IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE product_category_name IS NULL) / COUNT(*), 4) FROM raw.products
UNION ALL
SELECT 'geolocation', 'geolocation_zip_code_prefix', COUNT(*), COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL),
       ROUND(100.0 * COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) / COUNT(*), 4) FROM raw.geolocation
ORDER BY table_name, column_name;

-- Missing order timestamps by status.
SELECT
    order_status,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS missing_approved,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS missing_carrier,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_customer_delivery
FROM raw.orders
GROUP BY order_status
ORDER BY n_orders DESC;
