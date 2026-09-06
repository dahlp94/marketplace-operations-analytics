-- One row per ZIP prefix seen in customers, sellers, or geolocation.

DROP TABLE IF EXISTS analytics.dim_geography;

CREATE TABLE analytics.dim_geography AS
WITH zip_prefixes AS (
    SELECT zip_code_prefix
    FROM stg.geolocation_zip

    UNION

    SELECT customer_zip_code_prefix
    FROM raw.customers

    UNION

    SELECT seller_zip_code_prefix
    FROM raw.sellers
)
SELECT
    z.zip_code_prefix,
    g.latitude,
    g.longitude,
    COALESCE(g.n_geolocation_rows, 0) AS n_geolocation_rows,
    COALESCE(g.has_conflicting_states, FALSE) AS has_conflicting_states,
    g.zip_code_prefix IS NULL AS geo_unmatched
FROM zip_prefixes z
LEFT JOIN stg.geolocation_zip g
    ON g.zip_code_prefix = z.zip_code_prefix
ORDER BY z.zip_code_prefix;
