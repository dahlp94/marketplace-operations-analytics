-- Seller-order metrics.
-- Grain: one row per (seller_id, order_id).
-- Items are aggregated first so order-level outcomes are not duplicated.

DROP TABLE IF EXISTS metrics.kpi_seller_orders;

CREATE TABLE metrics.kpi_seller_orders AS
WITH seller_items AS (
    SELECT
        seller_id,
        order_id,
        COUNT(*)::integer AS seller_item_volume,
        SUM(price) AS seller_gmv,
        SUM(freight_value) AS seller_freight,
        SUM(item_side_value) AS seller_item_side_value
    FROM analytics.fact_order_items
    GROUP BY seller_id, order_id
)
SELECT
    s.seller_id,
    s.order_id,
    o.purchase_date,
    o.purchase_month,
    o.is_comparable_trend_window,
    s.seller_item_volume,
    s.seller_gmv,
    s.seller_freight,
    s.seller_item_side_value,
    o.n_sellers AS order_n_sellers,
    o.n_sellers > 1 AS is_multi_seller_order,
    o.is_delivered,
    o.is_delivery_performance_eligible,
    o.delivery_performance_exclusion_reason,
    o.delivery_class,
    o.is_on_time,
    o.is_late,
    o.delivery_delay_days,
    o.late_days,
    o.is_purchase_to_delivery_eligible,
    o.is_seller_handling_eligible,
    o.is_carrier_transit_eligible,
    o.purchase_to_delivery_days,
    o.seller_handling_days,
    o.carrier_transit_days,
    o.promised_window_days,
    CASE WHEN o.is_late THEN s.seller_gmv END AS seller_late_gmv,
    o.has_usable_review,
    o.order_review_score,
    o.is_negative_review,
    o.review_band
FROM seller_items s
JOIN metrics.kpi_orders o
    ON o.order_id = s.order_id;
