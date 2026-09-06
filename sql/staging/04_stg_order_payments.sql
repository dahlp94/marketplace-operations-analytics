DROP TABLE IF EXISTS stg.order_payments;

CREATE TABLE stg.order_payments AS
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM raw.order_payments;