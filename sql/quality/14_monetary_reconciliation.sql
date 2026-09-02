-- Reconcile item-side value and payment value at order grain.
-- Items and payments are aggregated separately before comparison.

-- Basic monetary hygiene.
SELECT
    COUNT(*) AS item_rows,
    COUNT(*) FILTER (WHERE price < 0) AS negative_price,
    COUNT(*) FILTER (WHERE freight_value < 0) AS negative_freight,
    COUNT(*) FILTER (WHERE price = 0) AS zero_price,
    COUNT(*) FILTER (WHERE freight_value = 0) AS zero_freight
FROM raw.order_items;

SELECT
    COUNT(*) AS payment_rows,
    COUNT(*) FILTER (WHERE payment_value < 0) AS negative_payment,
    COUNT(*) FILTER (WHERE payment_value = 0) AS zero_payment,
    COUNT(*) FILTER (WHERE payment_installments = 0) AS zero_installments
FROM raw.order_payments;

-- Order-level reconciliation summary.
WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_value
    FROM raw.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM raw.order_payments
    GROUP BY order_id
),
compared AS (
    SELECT
        i.order_id,
        i.item_value,
        p.payment_value,
        p.payment_value - i.item_value AS gap
    FROM item_totals i
    JOIN payment_totals p
        ON p.order_id = i.order_id
)
SELECT
    COUNT(*) AS orders_compared,
    COUNT(*) FILTER (WHERE gap = 0) AS exact_match,
    COUNT(*) FILTER (WHERE ABS(gap) > 0 AND ABS(gap) <= 0.01) AS within_1_cent,
    COUNT(*) FILTER (WHERE ABS(gap) > 0.01 AND ABS(gap) <= 1) AS over_1_cent_to_1,
    COUNT(*) FILTER (WHERE ABS(gap) > 1) AS over_1,
    ROUND(AVG(gap), 4) AS mean_gap,
    ROUND(SUM(gap), 2) AS net_gap
FROM compared;

-- Reconciliation by order status.
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS item_value
    FROM raw.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    o.order_status,
    COUNT(*) AS n_orders,
    COUNT(*) FILTER (
        WHERE ABS(p.payment_value - i.item_value) <= 0.01
    ) AS matched_within_1_cent,
    COUNT(*) FILTER (
        WHERE ABS(p.payment_value - i.item_value) > 0.01
    ) AS mismatch_over_1_cent,
    ROUND(SUM(p.payment_value - i.item_value), 2) AS net_gap
FROM raw.orders o
JOIN item_totals i
    ON i.order_id = o.order_id
JOIN payment_totals p
    ON p.order_id = o.order_id
GROUP BY o.order_status
ORDER BY n_orders DESC;

-- Largest order-level differences for manual inspection.
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS item_value
    FROM raw.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    i.item_value,
    p.payment_value,
    p.payment_value - i.item_value AS gap
FROM raw.orders o
JOIN item_totals i
    ON i.order_id = o.order_id
JOIN payment_totals p
    ON p.order_id = o.order_id
ORDER BY ABS(p.payment_value - i.item_value) DESC
LIMIT 10;
