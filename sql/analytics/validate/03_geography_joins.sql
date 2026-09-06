-- Geography joins must not multiply customer or seller rows.

SELECT
    'customers' AS entity,

    (SELECT COUNT(*)
     FROM analytics.dim_customer) AS native_rows,

    (
        SELECT COUNT(*)
        FROM analytics.dim_customer c
        JOIN analytics.dim_geography g
            ON g.zip_code_prefix = c.zip_code_prefix
    ) AS joined_rows,

    (
        SELECT COUNT(*)
        FROM analytics.dim_customer c
        JOIN analytics.dim_geography g
            ON g.zip_code_prefix = c.zip_code_prefix
        WHERE g.geo_unmatched
    ) AS unmatched_rows

UNION ALL

SELECT
    'sellers',

    (SELECT COUNT(*)
     FROM analytics.dim_seller),

    (
        SELECT COUNT(*)
        FROM analytics.dim_seller s
        JOIN analytics.dim_geography g
            ON g.zip_code_prefix = s.zip_code_prefix
    ),

    (
        SELECT COUNT(*)
        FROM analytics.dim_seller s
        JOIN analytics.dim_geography g
            ON g.zip_code_prefix = s.zip_code_prefix
        WHERE g.geo_unmatched
    );