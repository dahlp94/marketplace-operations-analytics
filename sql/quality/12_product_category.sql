-- Investigate missing and untranslated product categories.

-- Product category coverage.
SELECT
    COUNT(*) AS products,
    COUNT(*) FILTER (
        WHERE p.product_category_name IS NULL
    ) AS missing_category,
    COUNT(*) FILTER (
        WHERE p.product_category_name IS NOT NULL
          AND t.product_category_name IS NULL
    ) AS untranslated_products,
    COUNT(DISTINCT p.product_category_name) FILTER (
        WHERE p.product_category_name IS NOT NULL
          AND t.product_category_name IS NULL
    ) AS untranslated_category_names
FROM raw.products p
LEFT JOIN raw.product_category_translation t
    ON t.product_category_name = p.product_category_name;


-- Marketplace exposure from products with no category.
SELECT
    COUNT(DISTINCT p.product_id) AS products,
    COUNT(i.order_item_id) AS item_rows,
    COUNT(DISTINCT i.order_id) AS orders,
    ROUND(SUM(i.price + i.freight_value), 2) AS item_side_value
FROM raw.products p
JOIN raw.order_items i
    ON i.product_id = p.product_id
WHERE p.product_category_name IS NULL;


-- Untranslated categories and their marketplace exposure.
SELECT
    p.product_category_name,
    COUNT(DISTINCT p.product_id) AS products,
    COUNT(i.order_item_id) AS item_rows,
    COUNT(DISTINCT i.order_id) AS orders,
    ROUND(SUM(i.price + i.freight_value), 2) AS item_side_value
FROM raw.products p
LEFT JOIN raw.product_category_translation t
    ON t.product_category_name = p.product_category_name
JOIN raw.order_items i
    ON i.product_id = p.product_id
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY item_rows DESC;
