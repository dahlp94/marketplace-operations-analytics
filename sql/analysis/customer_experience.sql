-- Customer experience: delivery performance associated with review outcomes.
-- Grain: order. Certified review and delivery fields are reused, not redefined.

DROP TABLE IF EXISTS analysis.segment_review_performance;
DROP TABLE IF EXISTS analysis.delivery_review_month;
DROP TABLE IF EXISTS analysis.review_selection;
DROP TABLE IF EXISTS analysis.delay_band_reviews;
DROP TABLE IF EXISTS analysis.review_score_distribution;
DROP TABLE IF EXISTS analysis.review_coverage;
DROP VIEW IF EXISTS _cx_orders;


CREATE TEMP VIEW _cx_orders AS
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
            AS primary_product_category,
        COUNT(*)::integer AS n_categories_on_order
    FROM category_value
    GROUP BY order_id
)
SELECT
    o.*,
    CASE
        WHEN delivery_delay_days <= -15 THEN 'early_15plus'
        WHEN delivery_delay_days <= -8  THEN 'early_8_14'
        WHEN delivery_delay_days <= -4  THEN 'early_4_7'
        WHEN delivery_delay_days <= -1  THEN 'early_1_3'
        WHEN delivery_delay_days = 0    THEN 'on_time'
        WHEN delivery_delay_days <= 3   THEN 'late_1_3'
        WHEN delivery_delay_days <= 7   THEN 'late_4_7'
        WHEN delivery_delay_days <= 14  THEN 'late_8_14'
        WHEN delivery_delay_days <= 30  THEN 'late_15_30'
        ELSE 'late_31plus'
    END AS delay_band,
    CASE
        WHEN delivery_delay_days <= -15 THEN 1
        WHEN delivery_delay_days <= -8  THEN 2
        WHEN delivery_delay_days <= -4  THEN 3
        WHEN delivery_delay_days <= -1  THEN 4
        WHEN delivery_delay_days = 0    THEN 5
        WHEN delivery_delay_days <= 3   THEN 6
        WHEN delivery_delay_days <= 7   THEN 7
        WHEN delivery_delay_days <= 14  THEN 8
        WHEN delivery_delay_days <= 30  THEN 9
        ELSE 10
    END AS delay_band_sort,
    CASE
        WHEN gmv < 50  THEN 'lt_50'
        WHEN gmv < 100 THEN '50_99'
        WHEN gmv < 200 THEN '100_199'
        ELSE '200_plus'
    END AS gmv_band,
    CASE
        WHEN gmv < 50  THEN 1
        WHEN gmv < 100 THEN 2
        WHEN gmv < 200 THEN 3
        ELSE 4
    END AS gmv_band_sort,
    CASE WHEN is_repeat_order THEN 'repeat_order' ELSE 'first_order' END
        AS purchase_sequence,
    COALESCE(c.state, '(unknown_state)') AS customer_state,
    pc.primary_product_category,
    pc.n_categories_on_order
FROM metrics.kpi_orders o
JOIN analytics.dim_customer c USING (customer_id)
LEFT JOIN primary_category pc USING (order_id);


CREATE TABLE analysis.review_coverage AS
WITH tagged AS (
    SELECT p.population, o.*
    FROM metrics.kpi_orders o
    CROSS JOIN LATERAL (
        VALUES
            ('all_orders'::text, TRUE),
            ('delivered_orders', o.is_delivered),
            ('delivery_performance_eligible', o.is_delivery_performance_eligible),
            (
                'comparable_eligible',
                o.is_delivery_performance_eligible AND o.is_comparable_trend_window
            ),
            ('first_orders', NOT o.is_repeat_order),
            ('repeat_orders', o.is_repeat_order)
    ) p(population, include_row)
    WHERE p.include_row
)
SELECT
    population,
    COUNT(*)::integer AS orders,
    COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed_orders,
    COUNT(*) FILTER (WHERE NOT has_usable_review)::integer AS without_usable_review,
    COUNT(*) FILTER (WHERE review_unusable_only)::integer AS unusable_only_orders,
    COUNT(*) FILTER (WHERE has_no_review)::integer AS no_review_orders,
    COUNT(*) FILTER (WHERE has_usable_review)::numeric / NULLIF(COUNT(*), 0)
        AS review_coverage,
    COUNT(*) FILTER (WHERE is_negative_review)::integer AS negative_review_orders,
    COUNT(*) FILTER (WHERE is_negative_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate,
    AVG(order_review_score) AS avg_review_score
FROM tagged
GROUP BY population;


CREATE TABLE analysis.review_score_distribution AS
SELECT
    delivery_class,
    order_review_score AS review_score,
    COUNT(*)::integer AS reviewed_orders,
    COUNT(*)::numeric
        / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY delivery_class), 0)
        AS pct_within_delivery_class
FROM metrics.kpi_orders
WHERE is_delivery_performance_eligible
  AND has_usable_review
GROUP BY delivery_class, order_review_score;


CREATE TABLE analysis.delay_band_reviews AS
SELECT
    delay_band,
    delay_band_sort,
    COUNT(*)::integer AS eligible_orders,
    COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed_orders,
    COUNT(*) FILTER (WHERE NOT has_usable_review)::integer AS without_usable_review,
    COUNT(*) FILTER (WHERE is_negative_review)::integer AS negative_review_orders,
    COUNT(*) FILTER (WHERE is_negative_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate,
    AVG(order_review_score) AS avg_review_score,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_review_score)
        AS median_review_score,
    ROUND(SUM(gmv), 2) AS gmv,
    COUNT(*) FILTER (WHERE has_usable_review) < 100 AS is_low_sample
FROM _cx_orders
WHERE is_delivery_performance_eligible
GROUP BY delay_band, delay_band_sort;


CREATE TABLE analysis.review_selection AS
SELECT
    CASE WHEN has_usable_review THEN 'reviewed' ELSE 'unreviewed' END
        AS review_availability,
    COUNT(*)::integer AS delivered_orders,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::integer AS eligible_orders,
    COUNT(*) FILTER (WHERE is_late)::integer AS late_orders,
    COUNT(*) FILTER (WHERE is_late)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0)
        AS late_delivery_rate,
    COUNT(*) FILTER (WHERE is_repeat_order)::integer AS repeat_orders,
    COUNT(*) FILTER (WHERE is_repeat_order)::numeric / NULLIF(COUNT(*), 0)
        AS repeat_share,
    AVG(gmv) AS avg_gmv,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gmv) AS median_gmv,
    ROUND(SUM(gmv), 2) AS gmv
FROM metrics.kpi_orders
WHERE is_delivered
GROUP BY 1;


CREATE TABLE analysis.delivery_review_month AS
SELECT
    purchase_month,
    BOOL_OR(is_comparable_trend_window) AS is_comparable_trend_window,
    COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::integer AS eligible_orders,
    COUNT(*) FILTER (WHERE is_late)::integer AS late_orders,
    COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed_orders,
    COUNT(*) FILTER (WHERE is_negative_review)::integer AS negative_review_orders,
    COUNT(*) FILTER (WHERE is_negative_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate,
    AVG(order_review_score) AS avg_review_score,
    COUNT(*) FILTER (
        WHERE delivery_class = 'early' AND has_usable_review
    )::integer AS early_reviewed_orders,
    COUNT(*) FILTER (
        WHERE delivery_class = 'early' AND is_negative_review
    )::integer AS early_negative_review_orders,
    COUNT(*) FILTER (
        WHERE delivery_class = 'early' AND is_negative_review
    )::numeric
        / NULLIF(
            COUNT(*) FILTER (WHERE delivery_class = 'early' AND has_usable_review),
            0
        ) AS early_negative_review_rate,
    COUNT(*) FILTER (
        WHERE is_late AND has_usable_review
    )::integer AS late_reviewed_orders,
    COUNT(*) FILTER (
        WHERE is_late AND is_negative_review
    )::integer AS late_negative_review_orders,
    COUNT(*) FILTER (
        WHERE is_late AND is_negative_review
    )::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_late AND has_usable_review), 0)
        AS late_negative_review_rate
FROM metrics.kpi_orders
GROUP BY purchase_month;


CREATE TABLE analysis.segment_review_performance AS
WITH segmented AS (
    SELECT
        s.segment_type,
        s.segment_key,
        s.segment_sort,
        o.*
    FROM _cx_orders o
    CROSS JOIN LATERAL (
        VALUES
            (
                'purchase_sequence'::text,
                o.purchase_sequence,
                CASE WHEN o.is_repeat_order THEN 2 ELSE 1 END
            ),
            ('gmv_band', o.gmv_band, o.gmv_band_sort),
            ('customer_state', o.customer_state, 0),
            (
                'product_category',
                COALESCE(o.primary_product_category, '(missing_category)'),
                0
            )
    ) s(segment_type, segment_key, segment_sort)
    WHERE o.is_delivery_performance_eligible
)
SELECT
    segment_type,
    segment_key,
    segment_sort,
    COUNT(*)::integer AS eligible_orders,
    COUNT(*) FILTER (WHERE is_late)::integer AS late_orders,
    COUNT(*) FILTER (WHERE is_late)::numeric / NULLIF(COUNT(*), 0)
        AS late_delivery_rate,
    COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed_orders,
    COUNT(*) FILTER (WHERE NOT has_usable_review)::integer AS without_usable_review,
    COUNT(*) FILTER (WHERE has_usable_review)::numeric / NULLIF(COUNT(*), 0)
        AS review_coverage,
    COUNT(*) FILTER (WHERE is_negative_review)::integer AS negative_review_orders,
    COUNT(*) FILTER (WHERE is_negative_review)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
        AS negative_review_rate,
    AVG(order_review_score) AS avg_review_score,
    COUNT(*) FILTER (
        WHERE delivery_class = 'early' AND has_usable_review
    )::integer AS early_reviewed_orders,
    COUNT(*) FILTER (
        WHERE delivery_class = 'early' AND is_negative_review
    )::integer AS early_negative_review_orders,
    COUNT(*) FILTER (
        WHERE delivery_class = 'early' AND is_negative_review
    )::numeric
        / NULLIF(
            COUNT(*) FILTER (WHERE delivery_class = 'early' AND has_usable_review),
            0
        ) AS early_negative_review_rate,
    COUNT(*) FILTER (
        WHERE delivery_class = 'on_time' AND has_usable_review
    )::integer AS on_time_reviewed_orders,
    COUNT(*) FILTER (
        WHERE is_late AND has_usable_review
    )::integer AS late_reviewed_orders,
    COUNT(*) FILTER (
        WHERE is_late AND is_negative_review
    )::integer AS late_negative_review_orders,
    COUNT(*) FILTER (
        WHERE is_late AND is_negative_review
    )::numeric
        / NULLIF(COUNT(*) FILTER (WHERE is_late AND has_usable_review), 0)
        AS late_negative_review_rate,
    ROUND(SUM(gmv), 2) AS gmv,
    COUNT(*) FILTER (WHERE n_categories_on_order > 1)::integer
        AS multi_category_orders,
    COUNT(*) FILTER (WHERE has_usable_review) < 100 AS is_low_sample
FROM segmented
GROUP BY segment_type, segment_key, segment_sort;


ALTER TABLE analysis.review_coverage
    ADD PRIMARY KEY (population);
ALTER TABLE analysis.review_score_distribution
    ADD PRIMARY KEY (delivery_class, review_score);
ALTER TABLE analysis.delay_band_reviews
    ADD PRIMARY KEY (delay_band);
ALTER TABLE analysis.review_selection
    ADD PRIMARY KEY (review_availability);
ALTER TABLE analysis.delivery_review_month
    ADD PRIMARY KEY (purchase_month);
ALTER TABLE analysis.segment_review_performance
    ADD PRIMARY KEY (segment_type, segment_key);

DROP VIEW IF EXISTS _cx_orders;
