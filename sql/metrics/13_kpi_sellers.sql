-- Seller-level base metrics.
-- Grain: one row per seller_id.
-- Late rate and marketplace late contribution are intentionally separate.

DROP TABLE IF EXISTS metrics.kpi_sellers;

CREATE TABLE metrics.kpi_sellers AS
WITH seller_agg AS (
    SELECT
        seller_id,
        COUNT(*)::integer AS seller_order_volume,
        SUM(seller_item_volume)::integer AS seller_item_volume,
        COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::integer
            AS delivery_eligible_seller_orders,
        COUNT(*) FILTER (WHERE is_late)::integer AS late_seller_orders,
        COUNT(*) FILTER (WHERE is_on_time)::integer AS on_time_seller_orders,
        SUM(seller_gmv) AS seller_gmv,
        SUM(seller_freight) AS seller_freight,
        SUM(seller_gmv) FILTER (WHERE is_delivery_performance_eligible)
            AS seller_gmv_delivery_eligible,
        SUM(seller_late_gmv) AS seller_late_gmv,
        COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed_seller_orders,
        COUNT(*) FILTER (WHERE is_negative_review)::integer
            AS negative_review_seller_orders
    FROM metrics.kpi_seller_orders
    GROUP BY seller_id
),
marketplace AS (
    SELECT SUM(late_seller_orders)::integer AS late_seller_orders
    FROM seller_agg
)
SELECT
    d.seller_id,
    COALESCE(a.seller_order_volume, 0) AS seller_order_volume,
    COALESCE(a.seller_item_volume, 0) AS seller_item_volume,
    COALESCE(a.delivery_eligible_seller_orders, 0) AS delivery_eligible_seller_orders,
    COALESCE(a.late_seller_orders, 0) AS late_seller_orders,
    COALESCE(a.on_time_seller_orders, 0) AS on_time_seller_orders,

    a.late_seller_orders::numeric
        / NULLIF(a.delivery_eligible_seller_orders, 0) AS seller_late_rate,

    COALESCE(a.late_seller_orders, 0)::numeric
        / NULLIF(m.late_seller_orders, 0) AS seller_late_contribution,

    m.late_seller_orders AS marketplace_late_seller_orders,
    a.seller_gmv,
    a.seller_freight,
    a.seller_gmv_delivery_eligible,
    a.seller_late_gmv,
    COALESCE(a.reviewed_seller_orders, 0) AS reviewed_seller_orders,
    COALESCE(a.negative_review_seller_orders, 0) AS negative_review_seller_orders,

    a.negative_review_seller_orders::numeric
        / NULLIF(a.reviewed_seller_orders, 0) AS seller_negative_review_rate
FROM analytics.dim_seller d
LEFT JOIN seller_agg a
    ON a.seller_id = d.seller_id
CROSS JOIN marketplace m;
