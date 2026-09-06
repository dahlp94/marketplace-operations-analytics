DROP TABLE IF EXISTS stg.order_items;

CREATE TABLE stg.order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    (price + freight_value) AS item_side_value,
    (freight_value = 0) AS is_zero_freight
FROM raw.order_items;
