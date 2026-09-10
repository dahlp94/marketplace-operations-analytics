-- Fulfillment root-cause analysis.
-- Uses certified metrics.* fields; KPI definitions are not redefined here.

DROP TABLE IF EXISTS analysis.segment_fulfillment_month;
DROP TABLE IF EXISTS analysis.segment_fulfillment_performance;
DROP TABLE IF EXISTS analysis.fulfillment_decomposition;
DROP TABLE IF EXISTS analysis.fulfillment_month;
DROP VIEW IF EXISTS _segment_fulfillment_base;


-- Monthly marketplace fulfillment trends.
CREATE TABLE analysis.fulfillment_month AS
SELECT
    r.purchase_month,
    r.is_comparable_trend_window,
    r.coverage_class,
    COUNT(*) FILTER (WHERE o.is_delivery_performance_eligible)::INTEGER
        AS delivery_performance_eligible,
    COUNT(*) FILTER (WHERE o.is_late)::INTEGER AS late_count,
    COUNT(*) FILTER (WHERE o.is_late)::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE o.is_delivery_performance_eligible), 0)
        AS late_delivery_rate,
    ROUND(SUM(o.gmv), 2) AS gmv,
    ROUND(SUM(o.late_gmv), 2) AS late_gmv,

    COUNT(*) FILTER (WHERE o.is_seller_handling_eligible)::INTEGER
        AS seller_handling_eligible,
    AVG(o.seller_handling_days) AS avg_seller_handling_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.seller_handling_days)
        AS median_seller_handling_days,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.seller_handling_days)
        AS p90_seller_handling_days,

    COUNT(*) FILTER (WHERE o.is_carrier_transit_eligible)::INTEGER
        AS carrier_transit_eligible,
    AVG(o.carrier_transit_days) AS avg_carrier_transit_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.carrier_transit_days)
        AS median_carrier_transit_days,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.carrier_transit_days)
        AS p90_carrier_transit_days,

    COUNT(*) FILTER (WHERE o.is_purchase_to_delivery_eligible)::INTEGER
        AS purchase_to_delivery_eligible,
    AVG(o.purchase_to_delivery_days) AS avg_purchase_to_delivery_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.purchase_to_delivery_days)
        AS median_purchase_to_delivery_days,

    COUNT(o.promised_window_days)::INTEGER AS promised_window_eligible,
    AVG(o.promised_window_days) AS avg_promised_window_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.promised_window_days)
        AS median_promised_window_days,

    AVG(o.delivery_delay_days) AS avg_delivery_delay_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.delivery_delay_days)
        AS median_delivery_delay_days,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY o.delivery_delay_days)
        AS p90_delivery_delay_days
FROM analysis.reporting_month r
LEFT JOIN metrics.kpi_orders o USING (purchase_month)
GROUP BY r.purchase_month, r.is_comparable_trend_window, r.coverage_class;


-- Fulfillment components by delivery outcome for the full extract and
-- the comparable trend window.
CREATE TABLE analysis.fulfillment_decomposition AS
SELECT
    p.analysis_period,
    o.delivery_class,
    COUNT(*)::INTEGER AS eligible_orders,
    COUNT(*) FILTER (WHERE o.is_seller_handling_eligible)::INTEGER
        AS seller_handling_eligible,
    COUNT(*) FILTER (WHERE o.is_carrier_transit_eligible)::INTEGER
        AS carrier_transit_eligible,
    COUNT(*) FILTER (WHERE o.is_purchase_to_delivery_eligible)::INTEGER
        AS purchase_to_delivery_eligible,
    AVG(o.seller_handling_days) AS avg_seller_handling_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.seller_handling_days)
        AS median_seller_handling_days,
    AVG(o.carrier_transit_days) AS avg_carrier_transit_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.carrier_transit_days)
        AS median_carrier_transit_days,
    AVG(o.purchase_to_delivery_days) AS avg_purchase_to_delivery_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.purchase_to_delivery_days)
        AS median_purchase_to_delivery_days,
    AVG(o.promised_window_days) AS avg_promised_window_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.promised_window_days)
        AS median_promised_window_days,
    AVG(o.delivery_delay_days) AS avg_delivery_delay_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY o.delivery_delay_days)
        AS median_delivery_delay_days,
    ROUND(SUM(o.gmv), 2) AS gmv,
    ROUND(SUM(o.late_gmv), 2) AS late_gmv
FROM metrics.kpi_orders o
CROSS JOIN (
    VALUES ('full_extract'::TEXT), ('comparable_trend_window'::TEXT)
) AS p(analysis_period)
WHERE o.is_delivery_performance_eligible
  AND (
      p.analysis_period = 'full_extract'
      OR o.is_comparable_trend_window
  )
GROUP BY p.analysis_period, o.delivery_class;


-- Reusable normalized rows for segment analysis. The row grain differs by
-- segment_type and is recorded in unit_grain.
CREATE TEMP VIEW _segment_fulfillment_base AS
WITH category_orders AS (
    SELECT
        i.seller_id,
        i.order_id,
        COALESCE(
            p.product_category,
            '(missing_category)'
        ) AS product_category,
        SUM(i.price) AS category_gmv
    FROM analytics.fact_order_items i
    JOIN analytics.dim_product p USING (product_id)
    GROUP BY
        i.seller_id,
        i.order_id,
        COALESCE(
            p.product_category,
            '(missing_category)'
        )
)
SELECT
    'customer_state'::TEXT AS segment_type,
    COALESCE(c.state, '(unknown_state)') AS segment_key,
    o.purchase_month,
    'order'::TEXT AS unit_grain,
    NULL::TEXT AS seller_id,
    o.is_delivery_performance_eligible,
    o.is_late,
    o.is_seller_handling_eligible,
    o.seller_handling_days,
    o.is_carrier_transit_eligible,
    o.carrier_transit_days,
    o.promised_window_days,
    o.purchase_to_delivery_days,
    o.gmv,
    o.late_gmv
FROM metrics.kpi_orders o
JOIN analytics.dim_customer c USING (customer_id)
WHERE o.is_comparable_trend_window

UNION ALL

SELECT
    'product_category',
    c.product_category,
    s.purchase_month,
    'seller_order_category',
    s.seller_id,
    s.is_delivery_performance_eligible,
    s.is_late,
    s.is_seller_handling_eligible,
    s.seller_handling_days,
    s.is_carrier_transit_eligible,
    s.carrier_transit_days,
    s.promised_window_days,
    s.purchase_to_delivery_days,
    c.category_gmv,
    CASE
        WHEN s.is_late THEN c.category_gmv
        ELSE 0
    END
FROM category_orders c
JOIN metrics.kpi_seller_orders s
  ON s.seller_id = c.seller_id
 AND s.order_id = c.order_id
WHERE s.is_comparable_trend_window

UNION ALL

SELECT
    'seller_activity_cohort',
    TO_CHAR(f.first_observed_activity_cohort, 'YYYY-MM'),
    s.purchase_month,
    'seller_order',
    s.seller_id,
    s.is_delivery_performance_eligible,
    s.is_late,
    s.is_seller_handling_eligible,
    s.seller_handling_days,
    s.is_carrier_transit_eligible,
    s.carrier_transit_days,
    s.promised_window_days,
    s.purchase_to_delivery_days,
    s.seller_gmv,
    s.seller_late_gmv
FROM metrics.kpi_seller_orders s
JOIN analysis.seller_first_observed f USING (seller_id)
WHERE s.is_comparable_trend_window;


-- Segment-level fulfillment performance for the comparable trend window.
CREATE TABLE analysis.segment_fulfillment_performance AS
SELECT
    segment_type,
    segment_key,
    unit_grain,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::INTEGER
        AS eligible_units,
    COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_units,
    COUNT(*) FILTER (WHERE is_late)::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0)
        AS late_rate,
    COUNT(*) FILTER (WHERE is_seller_handling_eligible)::INTEGER
        AS seller_handling_eligible,
    AVG(seller_handling_days) AS avg_seller_handling_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY seller_handling_days)
        AS median_seller_handling_days,
    COUNT(*) FILTER (WHERE is_carrier_transit_eligible)::INTEGER
        AS carrier_transit_eligible,
    AVG(carrier_transit_days) AS avg_carrier_transit_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY carrier_transit_days)
        AS median_carrier_transit_days,
    AVG(promised_window_days) AS avg_promised_window_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_window_days)
        AS median_promised_window_days,
    AVG(purchase_to_delivery_days) AS avg_purchase_to_delivery_days,
    ROUND(SUM(gmv), 2) AS gmv,
    ROUND(SUM(late_gmv), 2) AS late_gmv,
    CASE
        WHEN segment_type = 'customer_state' THEN NULL
        ELSE COUNT(DISTINCT seller_id)::INTEGER
    END AS n_sellers,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible) < 100
        AS is_low_sample
FROM _segment_fulfillment_base
GROUP BY segment_type, segment_key, unit_grain;


-- Monthly segment trends for the comparable trend window.
CREATE TABLE analysis.segment_fulfillment_month AS
SELECT
    segment_type,
    segment_key,
    purchase_month,
    unit_grain,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::INTEGER
        AS eligible_units,
    COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_units,
    COUNT(*) FILTER (WHERE is_late)::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0)
        AS late_rate,
    AVG(seller_handling_days) AS avg_seller_handling_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY seller_handling_days)
        AS median_seller_handling_days,
    AVG(carrier_transit_days) AS avg_carrier_transit_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY carrier_transit_days)
        AS median_carrier_transit_days,
    AVG(promised_window_days) AS avg_promised_window_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_window_days)
        AS median_promised_window_days,
    ROUND(SUM(gmv), 2) AS gmv,
    ROUND(SUM(late_gmv), 2) AS late_gmv,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible) < 50
        AS is_low_sample
FROM _segment_fulfillment_base
GROUP BY segment_type, segment_key, purchase_month, unit_grain;

DROP VIEW _segment_fulfillment_base;


ALTER TABLE analysis.fulfillment_month
    ADD PRIMARY KEY (purchase_month);

ALTER TABLE analysis.fulfillment_decomposition
    ADD PRIMARY KEY (analysis_period, delivery_class);

ALTER TABLE analysis.segment_fulfillment_performance
    ADD PRIMARY KEY (segment_type, segment_key);

ALTER TABLE analysis.segment_fulfillment_month
    ADD PRIMARY KEY (segment_type, segment_key, purchase_month);
