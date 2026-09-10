-- Validate seller concentration outputs against certified seller-order data.

\echo '===== contribution ====='
SELECT
    ROUND(SUM(seller_late_contribution), 10) AS contribution_sum,
    SUM(late_seller_orders) AS late_seller_orders,
    MAX(marketplace_late_seller_orders) AS marketplace_late
FROM analysis.seller_prioritization;

\echo '===== excess late ====='
SELECT
    ROUND(SUM(excess_late_marketplace)::numeric, 6) AS sum_excess,
    COUNT(*) FILTER (
        WHERE ROUND(expected_late_marketplace::numeric, 8)
           IS DISTINCT FROM ROUND(
               delivery_eligible_seller_orders * marketplace_seller_late_rate, 8
           )
    ) AS expected_mismatches,
    COUNT(*) FILTER (
        WHERE ROUND(excess_late_marketplace::numeric, 8)
           IS DISTINCT FROM ROUND(late_seller_orders - expected_late_marketplace, 8)
    ) AS excess_mismatches
FROM analysis.seller_prioritization;

\echo '===== seller spot checks ====='
SELECT
    p.seller_id,
    p.delivery_eligible_seller_orders,
    s.eligible,
    p.late_seller_orders,
    s.late,
    ROUND(p.expected_late_marketplace::numeric, 4) AS expected_late,
    ROUND(p.excess_late_marketplace::numeric, 4) AS excess_late
FROM analysis.seller_prioritization p
JOIN (
    SELECT
        seller_id,
        COUNT(*) FILTER (WHERE is_delivery_performance_eligible) AS eligible,
        COUNT(*) FILTER (WHERE is_late) AS late
    FROM metrics.kpi_seller_orders
    GROUP BY seller_id
) s USING (seller_id)
WHERE p.seller_id IN (
    '4a3ca9315b744ce9f8e9374361493884',
    '06a2c3af7b3aee5d69171b0e14f0ee87',
    '6560211a19b47992c3666cc44a7e94c0'
)
ORDER BY p.seller_id;

\echo '===== seller GMV ====='
SELECT COUNT(*) AS gmv_mismatches
FROM analysis.seller_prioritization p
JOIN (
    SELECT seller_id, ROUND(SUM(price)::numeric, 2) AS seller_gmv
    FROM analytics.fact_order_items
    GROUP BY seller_id
) s USING (seller_id)
WHERE ROUND(p.seller_gmv::numeric, 2) IS DISTINCT FROM s.seller_gmv;

\echo '===== watchlist ====='
SELECT
    COUNT(*) AS watchlist_rows,
    COUNT(*) FILTER (WHERE COALESCE(watchlist_reasons, '') = '') AS missing_reason,
    COUNT(*) FILTER (WHERE is_high_excess) AS high_excess,
    COUNT(*) FILTER (WHERE is_high_rate_high_volume) AS high_rate_high_volume,
    COUNT(*) FILTER (WHERE is_recently_deteriorating) AS recent_deterioration
FROM analysis.seller_watchlist;
