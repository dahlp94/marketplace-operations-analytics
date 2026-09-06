-- One row per order-scoped customer_id.
-- customer_unique_id is the durable buyer identifier across orders.

DROP TABLE IF EXISTS analytics.dim_customer;

CREATE TABLE analytics.dim_customer AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix AS zip_code_prefix,
    customer_city AS city,
    customer_state AS state
FROM raw.customers;
