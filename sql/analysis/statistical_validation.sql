-- Statistical validation populations.
-- Reuses certified KPI fields and approved analysis outputs.

DROP TABLE IF EXISTS analysis.inference_rate_counts;
DROP TABLE IF EXISTS analysis.inference_orders;
DROP VIEW IF EXISTS _inference_orders;


CREATE TEMP VIEW _inference_orders AS
WITH category_value AS (
    SELECT
        i.order_id,
        COALESCE(p.product_category, '(missing_category)') AS product_category,
        SUM(i.price) AS category_gmv
    FROM analytics.fact_order_items i
    JOIN analytics.dim_product p USING (product_id)
    GROUP BY i.order_id, COALESCE(p.product_category, '(missing_category)')
),
primary_category AS (
    SELECT
        order_id,
        (ARRAY_AGG(product_category ORDER BY category_gmv DESC, product_category))[1]
            AS primary_product_category
    FROM category_value
    GROUP BY order_id
),
primary_seller AS (
    SELECT
        order_id,
        (ARRAY_AGG(seller_id ORDER BY price DESC, seller_id))[1] AS primary_seller_id
    FROM analytics.fact_order_items
    GROUP BY order_id
),
top_categories AS (
    SELECT pc.primary_product_category
    FROM metrics.kpi_orders o
    JOIN primary_category pc USING (order_id)
    WHERE o.is_delivery_performance_eligible
      AND o.has_usable_review
    GROUP BY pc.primary_product_category
    ORDER BY COUNT(*) DESC, pc.primary_product_category
    LIMIT 8
)
SELECT
    o.order_id,
    o.purchase_date,
    o.purchase_month,
    o.is_comparable_trend_window,
    o.is_delivered,
    o.is_delivery_performance_eligible,
    o.delivery_class,
    o.is_late,
    o.is_on_time,
    o.delivery_delay_days,
    o.late_days,
    o.has_usable_review,
    o.is_negative_review,
    o.order_review_score,
    o.gmv,
    o.n_sellers,
    o.n_sellers > 1 AS is_multi_seller,
    o.is_repeat_order,

    CASE
        WHEN o.delivery_delay_days IS NULL THEN NULL
        WHEN o.delivery_delay_days <= -15 THEN 'early_15plus'
        WHEN o.delivery_delay_days <= -8  THEN 'early_8_14'
        WHEN o.delivery_delay_days <= -4  THEN 'early_4_7'
        WHEN o.delivery_delay_days <= -1  THEN 'early_1_3'
        WHEN o.delivery_delay_days = 0    THEN 'on_time'
        WHEN o.delivery_delay_days <= 3   THEN 'late_1_3'
        WHEN o.delivery_delay_days <= 7   THEN 'late_4_7'
        WHEN o.delivery_delay_days <= 14  THEN 'late_8_14'
        WHEN o.delivery_delay_days <= 30  THEN 'late_15_30'
        ELSE 'late_31plus'
    END AS delay_band,

    CASE
        WHEN o.gmv < 50  THEN 'lt_50'
        WHEN o.gmv < 100 THEN '50_99'
        WHEN o.gmv < 200 THEN '100_199'
        ELSE '200_plus'
    END AS gmv_band,

    CASE
        WHEN o.delivery_class IN ('early', 'on_time') THEN o.delivery_class
        WHEN o.delivery_delay_days <= 3  THEN 'late_1_3'
        WHEN o.delivery_delay_days <= 7  THEN 'late_4_7'
        WHEN o.delivery_delay_days <= 14 THEN 'late_8_14'
        WHEN o.delivery_delay_days <= 30 THEN 'late_15_30'
        WHEN o.delivery_class = 'late'   THEN 'late_31plus'
    END AS delay_severity,

    COALESCE(c.state, '(unknown_state)') AS customer_state,
    CASE WHEN c.state IN ('SP', 'RJ', 'MG') THEN c.state ELSE 'other' END
        AS customer_state_group,

    COALESCE(pc.primary_product_category, '(missing_category)')
        AS primary_product_category,
    CASE
        WHEN pc.primary_product_category IN (
            SELECT primary_product_category FROM top_categories
        ) THEN pc.primary_product_category
        WHEN pc.primary_product_category IS NULL THEN '(missing_category)'
        ELSE 'other'
    END AS category_group,

    ps.primary_seller_id,
    w.seller_id IS NOT NULL AS is_watchlist_primary_seller,

    CASE
        WHEN o.purchase_date >= DATE '2017-02-01'
         AND o.purchase_date <  DATE '2017-09-01' THEN 'early_baseline'
        WHEN o.purchase_month = DATE '2017-11-01' THEN 'nov_2017'
        WHEN o.purchase_month IN (DATE '2018-02-01', DATE '2018-03-01')
            THEN 'feb_mar_2018'
        WHEN o.purchase_month = DATE '2018-08-01' THEN 'aug_2018'
        WHEN o.is_comparable_trend_window THEN 'other_comparable'
        ELSE 'outside_comparable_window'
    END AS period_group

FROM metrics.kpi_orders o
JOIN analytics.dim_customer c USING (customer_id)
LEFT JOIN primary_category pc USING (order_id)
LEFT JOIN primary_seller ps USING (order_id)
LEFT JOIN analysis.seller_watchlist w
    ON w.seller_id = ps.primary_seller_id
WHERE o.is_delivered;


CREATE TABLE analysis.inference_orders AS
SELECT * FROM _inference_orders;


CREATE TABLE analysis.inference_rate_counts AS

-- Marketplace late-delivery rates.
SELECT
    'marketplace_late_all_eligible'::text AS population,
    'order'::text AS grain,
    'Overall marketplace late rate'::text AS question,
    late_count::integer AS numerator,
    delivery_performance_eligible::integer AS denominator,
    late_delivery_rate AS rate
FROM metrics.kpi_marketplace

UNION ALL

SELECT
    'marketplace_late_comparable',
    'order',
    'Comparable-window marketplace late rate',
    COUNT(*) FILTER (WHERE is_late)::integer,
    COUNT(*)::integer,
    AVG(is_late::integer)
FROM metrics.kpi_orders
WHERE is_delivery_performance_eligible
  AND is_comparable_trend_window

UNION ALL

-- Key fulfillment periods from the approved root-cause analysis.
SELECT
    'late_' || period_group,
    'order',
    'Late rate in key fulfillment period',
    COUNT(*) FILTER (WHERE is_late)::integer,
    COUNT(*)::integer,
    AVG(is_late::integer)
FROM analysis.inference_orders
WHERE is_delivery_performance_eligible
  AND period_group IN ('early_baseline', 'nov_2017', 'feb_mar_2018', 'aug_2018')
GROUP BY period_group

UNION ALL

-- Customer-experience rates.
SELECT
    'negative_review_' || delivery_class,
    'order',
    'Negative-review rate by delivery class',
    negative_review_orders,
    reviewed_orders,
    negative_review_rate
FROM analysis.delivery_class_review_rates

UNION ALL

SELECT
    'negative_review_' || delay_band,
    'order',
    'Negative-review rate by late-delay severity',
    negative_review_orders,
    reviewed_orders,
    negative_review_rate
FROM analysis.delay_band_reviews
WHERE delay_band LIKE 'late_%'

UNION ALL

SELECT
    'late_among_' || review_availability || '_delivered',
    'order',
    'Late rate by review availability',
    late_orders,
    eligible_orders,
    late_delivery_rate
FROM analysis.review_selection

UNION ALL

-- Seller-prioritization comparison.
SELECT
    'watchlist_seller_order_late',
    'seller_order',
    'Pooled late rate among watchlist sellers',
    SUM(late_seller_orders)::integer,
    SUM(delivery_eligible_seller_orders)::integer,
    SUM(late_seller_orders)::numeric
        / NULLIF(SUM(delivery_eligible_seller_orders), 0)
FROM analysis.seller_watchlist

UNION ALL

SELECT
    'nonwatchlist_seller_order_late',
    'seller_order',
    'Pooled late rate among non-watchlist sellers',
    SUM(p.late_seller_orders)::integer,
    SUM(p.delivery_eligible_seller_orders)::integer,
    SUM(p.late_seller_orders)::numeric
        / NULLIF(SUM(p.delivery_eligible_seller_orders), 0)
FROM analysis.seller_prioritization p
WHERE NOT EXISTS (
    SELECT 1
    FROM analysis.seller_watchlist w
    WHERE w.seller_id = p.seller_id
);


ALTER TABLE analysis.inference_orders
    ADD PRIMARY KEY (order_id);

ALTER TABLE analysis.inference_rate_counts
    ADD PRIMARY KEY (population);

DROP VIEW IF EXISTS _inference_orders;
