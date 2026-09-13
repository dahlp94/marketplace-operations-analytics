-- Grain: (reporting_scope, product_category).
-- Category late units are not additive to marketplace late seller-orders.

CREATE VIEW dashboard.category_performance AS
SELECT
    'full_extract'::text AS reporting_scope,
    product_category,
    'seller_order_category'::text AS unit_grain,
    n_sellers::integer AS n_sellers,
    seller_category_orders::integer AS seller_category_orders,
    delivery_eligible_seller_orders::integer AS eligible_units,
    late_seller_orders::integer AS late_units,
    category_late_rate AS late_rate,
    category_gmv AS gmv,
    category_late_gmv AS late_gmv,
    NULL::numeric AS median_seller_handling_days,
    NULL::numeric AS median_carrier_transit_days,
    NULL::numeric AS median_promised_window_days,
    delivery_eligible_seller_orders < 100 AS is_low_sample
FROM analysis.category_performance

UNION ALL

SELECT
    'comparable_trend_window',
    segment_key,
    unit_grain,
    n_sellers,
    NULL::integer,
    eligible_units,
    late_units,
    late_rate,
    gmv,
    late_gmv,
    median_seller_handling_days,
    median_carrier_transit_days,
    median_promised_window_days,
    is_low_sample
FROM analysis.segment_fulfillment_performance
WHERE segment_type = 'product_category';
