-- Independent marketplace reconciliation from analytics.*.
-- metrics.* is used only as the comparison target.

WITH source AS (
    SELECT
        COUNT(*) AS all_orders,
        COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_orders,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
        ) AS eligible_orders,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NULL
        ) AS missing_actual_delivery,
        COUNT(*) FILTER (WHERE eligible_purchase_to_delivery) AS p2d_eligible,
        COUNT(*) FILTER (WHERE eligible_seller_handling) AS handling_eligible,
        COUNT(*) FILTER (WHERE eligible_carrier_transit) AS transit_eligible,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  < order_estimated_delivery_date::date
        ) AS early_count,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  = order_estimated_delivery_date::date
        ) AS exact_on_time_count,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  <= order_estimated_delivery_date::date
        ) AS on_time_count,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  > order_estimated_delivery_date::date
        ) AS late_count,
        ROUND(SUM(merchandise_value), 2) AS gmv,
        ROUND(SUM(freight_value), 2) AS freight_value,
        ROUND(SUM(collected_payment), 2) AS collected_payment,
        ROUND(SUM(merchandise_value) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
              AND order_delivered_customer_date::date
                  > order_estimated_delivery_date::date
        ), 2) AS late_gmv,
        COUNT(*) FILTER (WHERE n_usable_review_rows > 0) AS reviewed_orders,
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND n_usable_review_rows > 0
        ) AS reviewed_delivered_orders,
        COUNT(*) FILTER (
            WHERE n_usable_review_rows > 0
              AND order_review_score <= 2
        ) AS negative_reviews
    FROM analytics.fact_orders
)
SELECT
    s.all_orders = m.all_orders AS orders_match,
    s.delivered_orders = m.delivered_orders AS delivered_match,
    s.eligible_orders = m.delivery_performance_eligible AS eligible_match,
    s.missing_actual_delivery = m.excluded_missing_actual_delivery
        AS exclusions_match,
    s.p2d_eligible = m.purchase_to_delivery_eligible AS p2d_match,
    s.handling_eligible = m.seller_handling_eligible AS handling_match,
    s.transit_eligible = m.carrier_transit_eligible AS transit_match,
    s.early_count = m.early_count
        AND s.exact_on_time_count = m.exact_on_time_count
        AND s.on_time_count = m.on_time_count
        AND s.late_count = m.late_count AS delivery_counts_match,
    ROUND(s.on_time_count::numeric / NULLIF(s.eligible_orders, 0), 10)
        = ROUND(m.on_time_delivery_rate, 10) AS on_time_rate_match,
    ROUND(s.late_count::numeric / NULLIF(s.eligible_orders, 0), 10)
        = ROUND(m.late_delivery_rate, 10) AS late_rate_match,
    s.gmv = m.gmv
        AND s.freight_value = m.freight_value
        AND s.collected_payment = m.collected_payment
        AND s.late_gmv = m.late_gmv AS monetary_match,
    s.reviewed_orders = m.reviewed_orders
        AND s.reviewed_delivered_orders = m.reviewed_delivered_orders
        AND s.negative_reviews = m.negative_review_count AS review_counts_match,
    ROUND(s.reviewed_delivered_orders::numeric / NULLIF(s.delivered_orders, 0), 10)
        = ROUND(m.review_coverage, 10) AS review_coverage_match,
    ROUND(s.negative_reviews::numeric / NULLIF(s.reviewed_orders, 0), 10)
        = ROUND(m.negative_review_rate, 10) AS negative_review_rate_match
FROM source s
CROSS JOIN metrics.kpi_marketplace m;


-- Row-level delivery, duration, and review contracts.
WITH independent AS (
    SELECT
        order_id,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN CASE
                WHEN order_delivered_customer_date::date
                    < order_estimated_delivery_date::date THEN 'early'
                WHEN order_delivered_customer_date::date
                    = order_estimated_delivery_date::date THEN 'on_time'
                ELSE 'late'
            END
        END AS delivery_class,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN order_delivered_customer_date::date
                > order_estimated_delivery_date::date
        END AS is_late,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN order_delivered_customer_date::date
                - order_estimated_delivery_date::date
        END AS delay_days,
        CASE WHEN eligible_purchase_to_delivery THEN ROUND((
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date - order_purchase_timestamp
            )) / 86400.0
        )::numeric, 10) END AS p2d_days,
        CASE WHEN eligible_seller_handling THEN ROUND((
            EXTRACT(EPOCH FROM (
                order_delivered_carrier_date - order_approved_at
            )) / 86400.0
        )::numeric, 10) END AS handling_days,
        CASE WHEN eligible_carrier_transit THEN ROUND((
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date - order_delivered_carrier_date
            )) / 86400.0
        )::numeric, 10) END AS transit_days,
        CASE WHEN n_usable_review_rows > 0
             THEN order_review_score <= 2 END AS is_negative_review
    FROM analytics.fact_orders
)
SELECT
    COUNT(*) FILTER (
        WHERE i.delivery_class IS DISTINCT FROM k.delivery_class
    ) AS delivery_class_mismatches,
    COUNT(*) FILTER (
        WHERE i.is_late IS DISTINCT FROM k.is_late
    ) AS late_flag_mismatches,
    COUNT(*) FILTER (
        WHERE i.delay_days IS DISTINCT FROM k.delivery_delay_days
    ) AS delay_mismatches,
    COUNT(*) FILTER (
        WHERE i.p2d_days IS DISTINCT
              FROM ROUND(k.purchase_to_delivery_days::numeric, 10)
    ) AS p2d_mismatches,
    COUNT(*) FILTER (
        WHERE i.handling_days IS DISTINCT
              FROM ROUND(k.seller_handling_days::numeric, 10)
    ) AS handling_mismatches,
    COUNT(*) FILTER (
        WHERE i.transit_days IS DISTINCT
              FROM ROUND(k.carrier_transit_days::numeric, 10)
    ) AS transit_mismatches,
    COUNT(*) FILTER (
        WHERE i.is_negative_review IS DISTINCT FROM k.is_negative_review
    ) AS review_mismatches
FROM independent i
JOIN metrics.kpi_orders k USING (order_id);


-- Monetary totals at their natural grains.
SELECT
    ROUND((SELECT SUM(price) FROM analytics.fact_order_items), 2)
        = (SELECT gmv FROM metrics.kpi_marketplace) AS gmv_match,
    ROUND((SELECT SUM(freight_value) FROM analytics.fact_order_items), 2)
        = (SELECT freight_value FROM metrics.kpi_marketplace) AS freight_match,
    ROUND((SELECT SUM(payment_value) FROM analytics.fact_payments), 2)
        = (SELECT collected_payment FROM metrics.kpi_marketplace) AS payment_match;
