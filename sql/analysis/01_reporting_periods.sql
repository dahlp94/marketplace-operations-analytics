-- Reporting-month spine with coverage classification.
-- Grain: one calendar month.

DROP TABLE IF EXISTS analysis.reporting_month;

CREATE TABLE analysis.reporting_month AS
WITH bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(purchase_date))::date AS first_month,
        DATE_TRUNC('month', MAX(purchase_date))::date AS last_month
    FROM metrics.kpi_orders
)
SELECT
    month::date AS purchase_month,
    month::date >= DATE '2017-02-01'
        AND month::date < DATE '2018-09-01'
        AS is_comparable_trend_window,
    CASE
        WHEN month::date >= DATE '2017-02-01'
         AND month::date < DATE '2018-09-01'
            THEN 'full_comparable'
        WHEN month::date = DATE '2017-01-01'
            THEN 'partial_start'
        WHEN month::date >= DATE '2018-09-01'
            THEN 'sparse_tail'
        ELSE 'sparse_start'
    END AS coverage_class
FROM bounds
CROSS JOIN LATERAL generate_series(
    first_month,
    last_month,
    INTERVAL '1 month'
) AS month;
