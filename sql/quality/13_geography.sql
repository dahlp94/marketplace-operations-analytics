-- Investigate whether raw geolocation can safely support customer/seller enrichment.

-- ZIP-prefix multiplicity and conflicting labels.
WITH zip_stats AS (
    SELECT
        geolocation_zip_code_prefix,
        COUNT(*) AS n_rows,
        COUNT(DISTINCT LOWER(BTRIM(geolocation_city))) AS n_cities,
        COUNT(DISTINCT geolocation_state) AS n_states
    FROM raw.geolocation
    GROUP BY geolocation_zip_code_prefix
)
SELECT
    COUNT(*) AS zip_prefixes,
    COUNT(*) FILTER (WHERE n_rows > 1) AS zips_with_multiple_rows,
    COUNT(*) FILTER (WHERE n_cities > 1) AS zips_with_multiple_city_labels,
    COUNT(*) FILTER (WHERE n_states > 1) AS zips_with_multiple_states,
    MAX(n_rows) AS max_rows_per_zip
FROM zip_stats;

-- Customer and seller ZIP coverage against geolocation.
WITH geo_zips AS (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM raw.geolocation
)
SELECT
    'customers' AS source,
    COUNT(*) AS rows,
    COUNT(*) FILTER (WHERE g.geolocation_zip_code_prefix IS NULL) AS unmatched_rows,
    COUNT(DISTINCT c.customer_zip_code_prefix)
        FILTER (WHERE g.geolocation_zip_code_prefix IS NULL) AS unmatched_zip_prefixes
FROM raw.customers c
LEFT JOIN geo_zips g
    ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix

UNION ALL

SELECT
    'sellers',
    COUNT(*),
    COUNT(*) FILTER (WHERE g.geolocation_zip_code_prefix IS NULL),
    COUNT(DISTINCT s.seller_zip_code_prefix)
        FILTER (WHERE g.geolocation_zip_code_prefix IS NULL)
FROM raw.sellers s
LEFT JOIN geo_zips g
    ON g.geolocation_zip_code_prefix = s.seller_zip_code_prefix;

-- Sample ZIP prefixes with conflicting states.
SELECT
    geolocation_zip_code_prefix,
    COUNT(DISTINCT geolocation_state) AS n_states,
    STRING_AGG(DISTINCT geolocation_state, ',' ORDER BY geolocation_state) AS states,
    COUNT(*) AS n_rows
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(DISTINCT geolocation_state) > 1
ORDER BY n_states DESC, n_rows DESC
LIMIT 10;
