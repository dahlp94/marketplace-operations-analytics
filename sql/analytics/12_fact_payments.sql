-- One row per payment allocation.

DROP TABLE IF EXISTS analytics.fact_payments;

CREATE TABLE analytics.fact_payments AS
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM stg.order_payments;
