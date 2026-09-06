-- One row per marketplace seller.

DROP TABLE IF EXISTS analytics.dim_seller;

CREATE TABLE analytics.dim_seller AS
SELECT
    seller_id,
    seller_zip_code_prefix AS zip_code_prefix,
    seller_city AS city,
    seller_state AS state
FROM raw.sellers;
