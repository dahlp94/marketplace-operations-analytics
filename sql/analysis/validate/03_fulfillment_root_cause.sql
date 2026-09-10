-- Validate fulfillment root-cause outputs against certified KPI fields.

\echo '===== monthly reconciliation ====='
SELECT
    COUNT(*) AS month_rows,
    COUNT(*) FILTER (
        WHERE f.late_count IS DISTINCT FROM t.late_count
           OR f.delivery_performance_eligible IS DISTINCT FROM t.delivery_performance_eligible
           OR ROUND(f.late_delivery_rate::numeric, 10)
              IS DISTINCT FROM ROUND(t.late_delivery_rate::numeric, 10)
    ) AS late_mismatches,
    COUNT(*) FILTER (
        WHERE ROUND(f.avg_seller_handling_days::numeric, 10)
              IS DISTINCT FROM ROUND(m.avg_seller_handling_days::numeric, 10)
           OR ROUND(f.avg_carrier_transit_days::numeric, 10)
              IS DISTINCT FROM ROUND(m.avg_carrier_transit_days::numeric, 10)
           OR ROUND(f.avg_promised_window_days::numeric, 10)
              IS DISTINCT FROM ROUND(m.avg_promised_window_days::numeric, 10)
    ) AS duration_mismatches
FROM analysis.fulfillment_month f
JOIN analysis.marketplace_month_trend t USING (purchase_month)
JOIN metrics.kpi_marketplace_month m USING (purchase_month);

\echo '===== comparable-window totals ====='
WITH k AS (
    SELECT
        COUNT(*) FILTER (WHERE is_delivery_performance_eligible) AS eligible,
        COUNT(*) FILTER (WHERE is_late) AS late
    FROM metrics.kpi_orders
    WHERE is_comparable_trend_window
),
e AS (
    SELECT
        SUM(delivery_performance_eligible) AS eligible,
        SUM(late_count) AS late
    FROM analysis.fulfillment_month
    WHERE is_comparable_trend_window
)
SELECT k.eligible AS kpi_eligible, k.late AS kpi_late,
       e.eligible AS extract_eligible, e.late AS extract_late
FROM k CROSS JOIN e;

\echo '===== decomposition uses certified delivery_class ====='
WITH k AS (
    SELECT delivery_class, COUNT(*)::integer AS eligible_orders
    FROM metrics.kpi_orders
    WHERE is_comparable_trend_window
      AND is_delivery_performance_eligible
    GROUP BY delivery_class
)
SELECT d.delivery_class, d.eligible_orders, k.eligible_orders AS kpi_eligible
FROM analysis.fulfillment_decomposition d
JOIN k USING (delivery_class)
WHERE d.analysis_period = 'comparable_trend_window'
ORDER BY d.delivery_class;

\echo '===== sample order durations match fact_orders ====='
WITH s AS (
    SELECT
        o.order_id, o.purchase_month, o.delivery_class,
        o.seller_handling_days, o.carrier_transit_days, o.delivery_delay_days,
        EXTRACT(EPOCH FROM (f.order_delivered_carrier_date - f.order_approved_at))
            / 86400.0 AS source_handling_days,
        EXTRACT(EPOCH FROM (
            f.order_delivered_customer_date - f.order_delivered_carrier_date
        )) / 86400.0 AS source_transit_days,
        f.order_delivered_customer_date::date
            - f.order_estimated_delivery_date::date AS source_delay_days
    FROM metrics.kpi_orders o
    JOIN analytics.fact_orders f USING (order_id)
    WHERE o.order_id IN (
        '000c3e6612759851cc3cbb4b83257986',
        '00685d31ae12e47470ba5c18ba74f22c',
        '00137e170939bba5a3134e2386413108',
        '000e906b789b55f64edcb1f84030f90d',
        '00061f2a7bc09da83e415a52dc8a4af1',
        '0032d07457ae9c806c79368d7d9ce96b',
        '00024acbcdf0a6daa1e931b038114c75',
        '003a94f778ef8cfd50247c8c1b582257'
    )
)
SELECT
    order_id, delivery_class,
    ROUND(seller_handling_days::numeric, 10)
        = ROUND(source_handling_days::numeric, 10) AS handling_matches,
    ROUND(carrier_transit_days::numeric, 10)
        = ROUND(source_transit_days::numeric, 10) AS transit_matches,
    delivery_delay_days = source_delay_days AS delay_matches
FROM s
ORDER BY purchase_month, delivery_class;

\echo '===== low-sample flags ====='
SELECT
    segment_type,
    COUNT(*) AS n_segments,
    COUNT(*) FILTER (WHERE is_low_sample) AS low_sample_segments
FROM analysis.segment_fulfillment_performance
GROUP BY segment_type
ORDER BY segment_type;
