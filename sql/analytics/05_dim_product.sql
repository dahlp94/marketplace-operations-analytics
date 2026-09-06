-- One row per product with treated category labels from staging.

DROP TABLE IF EXISTS analytics.dim_product;

CREATE TABLE analytics.dim_product AS
SELECT
    product_id,
    product_category_name_source,
    product_category_name_english,
    product_category,
    category_assignment,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM stg.products;
