-- One row per ZIP prefix for safe geographic enrichment.

DROP TABLE IF EXISTS stg.geolocation_zip;

CREATE TABLE stg.geolocation_zip AS
SELECT
    geolocation_zip_code_prefix AS zip_code_prefix,
    PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY geolocation_lat) AS latitude,
    PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY geolocation_lng) AS longitude,
    COUNT(*)::INTEGER AS n_geolocation_rows,
    COUNT(DISTINCT geolocation_state) > 1 AS has_conflicting_states
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix;