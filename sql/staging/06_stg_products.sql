-- Apply the approved product-category fallback rule.

DROP TABLE IF EXISTS stg.products;

CREATE TABLE stg.products AS
SELECT
    p.product_id,
    p.product_category_name AS product_category_name_source,
    t.product_category_name_english,

    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'unknown'
    ) AS product_category,

    CASE
        WHEN t.product_category_name_english IS NOT NULL
            THEN 'translated'
        WHEN p.product_category_name IS NOT NULL
            THEN 'portuguese_fallback'
        ELSE 'unknown'
    END AS category_assignment,

    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm

FROM raw.products p
LEFT JOIN raw.product_category_translation t
    ON t.product_category_name = p.product_category_name;
