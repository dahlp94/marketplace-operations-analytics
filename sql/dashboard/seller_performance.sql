-- Seller performance for Operations and Seller Success.
-- Grain: one seller; monthly detail remains seller x month.

CREATE VIEW dashboard.seller_performance AS
SELECT
    p.seller_id,
    p.seller_state,
    p.primary_product_category,
    'seller_order'::text AS unit_grain,
    p.seller_order_volume,
    p.delivery_eligible_seller_orders,
    p.late_seller_orders,
    p.seller_late_rate,
    p.seller_late_contribution,
    p.marketplace_late_seller_orders,
    p.contribution_row_number,
    p.cumulative_late_contribution,
    p.seller_gmv,
    p.seller_late_gmv,
    p.reviewed_seller_orders,
    p.negative_review_seller_orders,
    p.seller_negative_review_rate,
    p.marketplace_seller_late_rate,
    p.expected_late_marketplace,
    p.excess_late_marketplace,
    p.excess_late_category,
    p.excess_late_destination,
    p.comparable_eligible_seller_orders,
    p.comparable_late_seller_orders,
    p.comparable_late_rate,
    p.late_rate_2018_07,
    p.eligible_2018_07,
    p.late_rate_2018_08,
    p.eligible_2018_08,
    p.late_rate_pp_change_latest_comparable,
    p.is_very_low_volume,
    p.is_below_watchlist_volume,
    p.is_high_excess,
    p.is_high_rate_high_volume,
    p.is_recently_deteriorating,
    p.is_high_excess OR p.is_high_rate_high_volume OR p.is_recently_deteriorating
        AS is_on_watchlist,
    CASE
        WHEN p.is_high_excess THEN 'investigate_high_excess'
        WHEN p.is_recently_deteriorating THEN 'monitor_recent_deterioration'
        WHEN p.is_high_rate_high_volume THEN 'review_high_rate_high_volume'
        ELSE 'not_on_watchlist'
    END AS investigation_queue,
    CONCAT_WS(
        '; ',
        CASE WHEN p.is_high_excess THEN 'high_excess_late' END,
        CASE WHEN p.is_high_rate_high_volume THEN 'high_rate_high_volume' END,
        CASE WHEN p.is_recently_deteriorating THEN 'recent_deterioration' END
    ) AS watchlist_reasons
FROM analysis.seller_prioritization p;

CREATE VIEW dashboard.seller_month AS
SELECT
    seller_id,
    purchase_month,
    is_comparable_trend_window,
    'seller_order'::text AS unit_grain,
    seller_order_volume,
    delivery_eligible_seller_orders,
    late_seller_orders,
    on_time_seller_orders,
    seller_late_rate,
    seller_gmv,
    seller_late_gmv,
    reviewed_seller_orders,
    negative_review_seller_orders,
    seller_negative_review_rate,
    prior_seller_late_rate,
    seller_late_rate_pp_change,
    months_since_prior_activity
FROM analysis.seller_month;
