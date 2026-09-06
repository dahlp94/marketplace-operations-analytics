-- Calendar dimension covering all order-related dates in the source.

DROP TABLE IF EXISTS analytics.dim_date;

CREATE TABLE analytics.dim_date AS
WITH dates AS (
    SELECT order_purchase_timestamp::date AS date_day
    FROM raw.orders

    UNION ALL

    SELECT order_estimated_delivery_date::date
    FROM raw.orders

    UNION ALL

    SELECT order_delivered_customer_date::date
    FROM raw.orders
    WHERE order_delivered_customer_date IS NOT NULL
),
bounds AS (
    SELECT
        MIN(date_day) AS min_date,
        MAX(date_day) AS max_date
    FROM dates
),
calendar AS (
    SELECT generate_series(
        min_date,
        max_date,
        INTERVAL '1 day'
    )::date AS date_day
    FROM bounds
)
SELECT
    date_day,
    TO_CHAR(date_day, 'YYYYMMDD')::INTEGER AS date_key,
    EXTRACT(YEAR FROM date_day)::INTEGER AS year,
    EXTRACT(QUARTER FROM date_day)::INTEGER AS quarter,
    EXTRACT(MONTH FROM date_day)::INTEGER AS month,
    TO_CHAR(date_day, 'FMMonth') AS month_name,
    TO_CHAR(date_day, 'IW')::INTEGER AS iso_week,
    EXTRACT(ISODOW FROM date_day)::INTEGER AS iso_day_of_week,
    TO_CHAR(date_day, 'FMDay') AS day_name,
    EXTRACT(ISODOW FROM date_day) IN (6, 7) AS is_weekend
FROM calendar
ORDER BY date_day;
