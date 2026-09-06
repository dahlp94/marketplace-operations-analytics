-- Independently reconcile monetary values from raw source data to analytics.

SELECT
    measure,
    raw_total,
    analytical_total,
    order_rollup,
    raw_total = analytical_total
        AND analytical_total = order_rollup AS reconciles
FROM (
    SELECT
        'merchandise_value' AS measure,
        (SELECT ROUND(SUM(price), 2) FROM raw.order_items) AS raw_total,
        (SELECT ROUND(SUM(price), 2) FROM analytics.fact_order_items) AS analytical_total,
        (SELECT ROUND(SUM(merchandise_value), 2) FROM analytics.fact_orders) AS order_rollup

    UNION ALL

    SELECT
        'freight_value',
        (SELECT ROUND(SUM(freight_value), 2) FROM raw.order_items),
        (SELECT ROUND(SUM(freight_value), 2) FROM analytics.fact_order_items),
        (SELECT ROUND(SUM(freight_value), 2) FROM analytics.fact_orders)

    UNION ALL

    SELECT
        'item_side_value',
        (SELECT ROUND(SUM(price + freight_value), 2) FROM raw.order_items),
        (SELECT ROUND(SUM(item_side_value), 2) FROM analytics.fact_order_items),
        (SELECT ROUND(SUM(item_side_value), 2) FROM analytics.fact_orders)

    UNION ALL

    SELECT
        'collected_payment',
        (SELECT ROUND(SUM(payment_value), 2) FROM raw.order_payments),
        (SELECT ROUND(SUM(payment_value), 2) FROM analytics.fact_payments),
        (SELECT ROUND(SUM(collected_payment), 2) FROM analytics.fact_orders)
) x
ORDER BY measure;


-- Recalculate the > R$0.01 order-level difference directly from raw child tables.

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_side_value
    FROM raw.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS collected_payment
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    (
        SELECT COUNT(*)
        FROM item_totals i
        JOIN payment_totals p
            ON p.order_id = i.order_id
        WHERE ABS(p.collected_payment - i.item_side_value) > 0.01
    ) AS raw_recalculation,

    (
        SELECT COUNT(*)
        FROM analytics.fact_orders
        WHERE monetary_diff_gt_tolerance
    ) AS analytical_flagged;
