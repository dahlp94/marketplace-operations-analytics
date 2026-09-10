-- Seller concentration, benchmark comparisons, and candidate watchlist.
-- Grain: one row per seller in seller_prioritization and seller_watchlist.

DROP TABLE IF EXISTS analysis.seller_watchlist;
DROP TABLE IF EXISTS analysis.seller_volume_threshold_sensitivity;
DROP TABLE IF EXISTS analysis.seller_prioritization;


CREATE TABLE analysis.seller_prioritization AS
WITH comparable AS (
    SELECT
        seller_id,
        COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::integer
            AS comparable_eligible_seller_orders,
        COUNT(*) FILTER (WHERE is_late)::integer
            AS comparable_late_seller_orders
    FROM metrics.kpi_seller_orders
    WHERE is_comparable_trend_window
    GROUP BY seller_id
),
benchmarks AS (
    SELECT
        SUM(late_seller_orders)::numeric
            / NULLIF(SUM(delivery_eligible_seller_orders), 0)
            AS marketplace_late_rate,
        MAX(marketplace_late_seller_orders) AS marketplace_late_seller_orders,
        (
            SELECT SUM(comparable_late_seller_orders)::numeric
                / NULLIF(SUM(comparable_eligible_seller_orders), 0)
            FROM comparable
        ) AS comparable_marketplace_late_rate
    FROM metrics.kpi_sellers
),
primary_category AS (
    SELECT
        sc.seller_id,
        sc.product_category AS primary_product_category,
        cp.category_late_rate
    FROM analysis.seller_category sc
    JOIN analysis.category_performance cp USING (product_category)
    WHERE sc.is_largest_gmv_category
),
destination AS (
    SELECT
        s.seller_id,
        SUM(st.late_delivery_rate)
            FILTER (WHERE s.is_delivery_performance_eligible)
            AS expected_late_destination
    FROM metrics.kpi_seller_orders s
    JOIN metrics.kpi_orders o USING (order_id)
    JOIN analytics.dim_customer c
        ON c.customer_id = o.customer_id
    JOIN analysis.customer_state_performance st
        ON st.customer_state = c.state
    GROUP BY s.seller_id
),
base AS (
    SELECT
        s.seller_id,
        d.state AS seller_state,
        p.primary_product_category,

        s.seller_order_volume,
        s.delivery_eligible_seller_orders,
        s.late_seller_orders,
        s.seller_late_rate,
        s.seller_late_contribution,
        s.marketplace_late_seller_orders,
        s.seller_gmv,
        s.seller_late_gmv,
        s.reviewed_seller_orders,
        s.negative_review_seller_orders,
        s.seller_negative_review_rate,

        c.contribution_row_number,
        c.cumulative_late_contribution,
        c.cumulative_late_gmv,
        c.cumulative_late_gmv_share,

        r.late_rate_2018_07,
        r.eligible_2018_07,
        r.late_rate_2018_08,
        r.eligible_2018_08,
        r.late_rate_pp_change_latest_comparable,

        b.marketplace_late_rate AS marketplace_seller_late_rate,
        p.category_late_rate,
        ss.seller_late_rate AS seller_state_late_rate,

        s.delivery_eligible_seller_orders * b.marketplace_late_rate
            AS expected_late_marketplace,
        s.late_seller_orders
            - s.delivery_eligible_seller_orders * b.marketplace_late_rate
            AS excess_late_marketplace,

        s.delivery_eligible_seller_orders * p.category_late_rate
            AS expected_late_category,
        s.late_seller_orders
            - s.delivery_eligible_seller_orders * p.category_late_rate
            AS excess_late_category,

        s.delivery_eligible_seller_orders * ss.seller_late_rate
            AS expected_late_seller_state,
        s.late_seller_orders
            - s.delivery_eligible_seller_orders * ss.seller_late_rate
            AS excess_late_seller_state,

        dest.expected_late_destination,
        s.late_seller_orders - dest.expected_late_destination
            AS excess_late_destination,

        cmp.comparable_eligible_seller_orders,
        cmp.comparable_late_seller_orders,
        cmp.comparable_late_seller_orders::numeric
            / NULLIF(cmp.comparable_eligible_seller_orders, 0)
            AS comparable_late_rate,
        b.comparable_marketplace_late_rate,
        cmp.comparable_eligible_seller_orders * b.comparable_marketplace_late_rate
            AS expected_late_comparable,
        cmp.comparable_late_seller_orders
            - cmp.comparable_eligible_seller_orders * b.comparable_marketplace_late_rate
            AS excess_late_comparable
    FROM metrics.kpi_sellers s
    JOIN analytics.dim_seller d USING (seller_id)
    LEFT JOIN analysis.seller_contribution c USING (seller_id)
    LEFT JOIN analysis.seller_rankings r USING (seller_id)
    LEFT JOIN analysis.seller_state_performance ss
        ON ss.seller_state = d.state
    LEFT JOIN primary_category p USING (seller_id)
    LEFT JOIN destination dest USING (seller_id)
    LEFT JOIN comparable cmp USING (seller_id)
    CROSS JOIN benchmarks b
)
SELECT
    *,

    delivery_eligible_seller_orders < 30 AS is_very_low_volume,
    delivery_eligible_seller_orders < 100 AS is_below_watchlist_volume,

    delivery_eligible_seller_orders >= 100
        AND seller_late_rate >= marketplace_seller_late_rate + 0.03
        AND late_seller_orders >= 30
        AS is_high_rate_high_volume,

    delivery_eligible_seller_orders BETWEEN 10 AND 99
        AND seller_late_rate >= marketplace_seller_late_rate + 0.10
        AS is_high_rate_low_volume,

    delivery_eligible_seller_orders >= 100
        AND late_seller_orders >= 50
        AND seller_late_rate < marketplace_seller_late_rate + 0.03
        AS is_moderate_rate_high_contribution,

    delivery_eligible_seller_orders >= 100
        AND excess_late_marketplace >= 15
        AS is_high_excess,

    COALESCE(eligible_2018_08, 0) >= 30
        AND late_rate_pp_change_latest_comparable >= 0.05
        AS is_recently_deteriorating
FROM base;


CREATE TABLE analysis.seller_watchlist AS
SELECT
    seller_id,
    seller_state,
    primary_product_category,
    delivery_eligible_seller_orders,
    late_seller_orders,
    seller_late_rate,
    seller_late_contribution,
    contribution_row_number,
    seller_gmv,
    seller_late_gmv,
    seller_negative_review_rate,
    expected_late_marketplace,
    excess_late_marketplace,
    excess_late_category,
    excess_late_destination,
    late_rate_2018_07,
    late_rate_2018_08,
    eligible_2018_08,
    late_rate_pp_change_latest_comparable,
    is_high_excess,
    is_high_rate_high_volume,
    is_recently_deteriorating,
    CONCAT_WS(
        '; ',
        CASE WHEN is_high_excess THEN 'high_excess_late' END,
        CASE WHEN is_high_rate_high_volume THEN 'high_rate_high_volume' END,
        CASE WHEN is_recently_deteriorating THEN 'recent_deterioration' END
    ) AS watchlist_reasons
FROM analysis.seller_prioritization
WHERE is_high_excess
   OR is_high_rate_high_volume
   OR is_recently_deteriorating;


CREATE TABLE analysis.seller_volume_threshold_sensitivity AS
SELECT
    threshold AS min_eligible_seller_orders,
    COUNT(*) FILTER (
        WHERE delivery_eligible_seller_orders >= threshold
    )::integer AS sellers_at_or_above,
    COALESCE(SUM(late_seller_orders) FILTER (
        WHERE delivery_eligible_seller_orders >= threshold
    ), 0)::integer AS late_seller_orders_kept,
    COALESCE(SUM(late_seller_orders) FILTER (
        WHERE delivery_eligible_seller_orders >= threshold
    ), 0)::numeric
        / NULLIF(MAX(marketplace_late_seller_orders), 0)
        AS share_of_marketplace_late_units,
    COUNT(*) FILTER (
        WHERE delivery_eligible_seller_orders >= threshold
          AND excess_late_marketplace >= 15
    )::integer AS sellers_with_excess_ge_15,
    COALESCE(SUM(excess_late_marketplace) FILTER (
        WHERE delivery_eligible_seller_orders >= threshold
          AND excess_late_marketplace >= 15
    ), 0) AS excess_late_among_those_sellers
FROM analysis.seller_prioritization
CROSS JOIN (
    VALUES (1), (10), (30), (50), (100), (200), (300)
) AS thresholds(threshold)
GROUP BY threshold;


ALTER TABLE analysis.seller_prioritization
    ADD PRIMARY KEY (seller_id);

ALTER TABLE analysis.seller_watchlist
    ADD PRIMARY KEY (seller_id);

ALTER TABLE analysis.seller_volume_threshold_sensitivity
    ADD PRIMARY KEY (min_eligible_seller_orders);
