-- Seller category context and first-observed activity cohorts.
-- Sellers may appear in multiple categories; first observed activity is not onboarding.

DROP TABLE IF EXISTS analysis.seller_category;
DROP TABLE IF EXISTS analysis.category_performance;
DROP TABLE IF EXISTS analysis.seller_first_observed;
DROP TABLE IF EXISTS analysis.seller_cohort_summary;

CREATE TABLE analysis.seller_category AS
WITH category_orders AS (
    SELECT
        i.seller_id,
        i.order_id,
        p.product_category,
        COUNT(*)::INTEGER AS category_item_volume,
        SUM(i.price) AS category_gmv
    FROM analytics.fact_order_items i
    JOIN analytics.dim_product p USING (product_id)
    GROUP BY i.seller_id, i.order_id, p.product_category
),
aggregated AS (
    SELECT
        c.seller_id,
        c.product_category,
        COUNT(*)::INTEGER AS seller_category_order_volume,
        COUNT(*) FILTER (
            WHERE s.is_delivery_performance_eligible
        )::INTEGER AS delivery_eligible_seller_orders,
        COUNT(*) FILTER (WHERE s.is_late)::INTEGER AS late_seller_orders,
        SUM(c.category_gmv) AS seller_category_gmv,
        SUM(c.category_gmv) FILTER (
            WHERE s.is_late
        ) AS seller_category_late_gmv,
        COUNT(*) FILTER (
            WHERE s.has_usable_review
        )::INTEGER AS reviewed_seller_orders,
        COUNT(*) FILTER (
            WHERE s.is_negative_review
        )::INTEGER AS negative_review_seller_orders
    FROM category_orders c
    JOIN metrics.kpi_seller_orders s
      ON s.seller_id = c.seller_id
     AND s.order_id = c.order_id
    GROUP BY c.seller_id, c.product_category
),
rates AS (
    SELECT
        *,
        late_seller_orders::NUMERIC
            / NULLIF(delivery_eligible_seller_orders, 0)
            AS seller_category_late_rate,
        SUM(late_seller_orders) OVER (
            PARTITION BY product_category
        ) AS category_late_seller_orders,
        COUNT(*) OVER (
            PARTITION BY seller_id
        ) AS seller_n_categories
    FROM aggregated
)
SELECT
    seller_id,
    product_category,
    seller_n_categories,
    seller_category_order_volume,
    delivery_eligible_seller_orders,
    late_seller_orders,
    seller_category_late_rate,
    seller_category_gmv,
    seller_category_late_gmv,
    reviewed_seller_orders,
    negative_review_seller_orders,
    late_seller_orders::NUMERIC
        / NULLIF(category_late_seller_orders, 0)
        AS category_late_contribution,
    RANK() OVER (
        PARTITION BY product_category
        ORDER BY seller_category_late_rate DESC NULLS LAST
    ) AS late_rate_rank_in_category,
    RANK() OVER (
        PARTITION BY product_category
        ORDER BY late_seller_orders DESC
    ) AS late_units_rank_in_category,
    ROW_NUMBER() OVER (
        PARTITION BY seller_id
        ORDER BY seller_category_gmv DESC, product_category
    ) = 1 AS is_largest_gmv_category
FROM rates;


CREATE TABLE analysis.category_performance AS
SELECT
    product_category,
    COUNT(DISTINCT seller_id) AS n_sellers,
    SUM(seller_category_order_volume) AS seller_category_orders,
    SUM(delivery_eligible_seller_orders) AS delivery_eligible_seller_orders,
    SUM(late_seller_orders) AS late_seller_orders,
    SUM(late_seller_orders)::NUMERIC
        / NULLIF(SUM(delivery_eligible_seller_orders), 0)
        AS category_late_rate,
    SUM(seller_category_gmv) AS category_gmv,
    SUM(seller_category_late_gmv) AS category_late_gmv
FROM analysis.seller_category
GROUP BY product_category;


CREATE TABLE analysis.seller_first_observed AS
SELECT
    seller_id,
    MIN(purchase_date) AS first_observed_purchase_date,
    DATE_TRUNC('month', MIN(purchase_date))::date
        AS first_observed_activity_cohort,
    MAX(purchase_date) AS last_observed_purchase_date,
    COUNT(*)::INTEGER AS observed_seller_orders
FROM metrics.kpi_seller_orders
GROUP BY seller_id;


CREATE TABLE analysis.seller_cohort_summary AS
SELECT
    f.first_observed_activity_cohort,
    COUNT(*)::INTEGER AS n_sellers,
    SUM(s.delivery_eligible_seller_orders) AS delivery_eligible_seller_orders,
    SUM(s.late_seller_orders) AS late_seller_orders,
    SUM(s.late_seller_orders)::NUMERIC
        / NULLIF(SUM(s.delivery_eligible_seller_orders), 0)
        AS cohort_late_rate,
    SUM(s.seller_gmv) AS cohort_gmv,
    SUM(s.seller_late_gmv) AS cohort_late_gmv
FROM analysis.seller_first_observed f
JOIN metrics.kpi_sellers s USING (seller_id)
GROUP BY f.first_observed_activity_cohort;
