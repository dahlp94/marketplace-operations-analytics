-- One row per order line.

DROP TABLE IF EXISTS analytics.fact_order_items;

CREATE TABLE analytics.fact_order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    item_side_value
FROM stg.order_items;
