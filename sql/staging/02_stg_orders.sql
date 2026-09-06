-- Order-level staging table with approved quality flags
-- and metric-specific eligibility rules.

DROP TABLE IF EXISTS stg.orders;

CREATE TABLE stg.orders AS
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    -- Source-quality flags.
    (
        order_delivered_carrier_date IS NOT NULL
        AND order_approved_at IS NOT NULL
        AND order_delivered_carrier_date < order_approved_at
    ) AS carrier_before_approval,

    (
        order_delivered_carrier_date IS NOT NULL
        AND order_delivered_carrier_date < order_purchase_timestamp
    ) AS carrier_before_purchase,

    (
        order_delivered_customer_date IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date < order_delivered_carrier_date
    ) AS customer_delivery_before_carrier,

    (
        (
            order_status = 'delivered'
            AND order_delivered_customer_date IS NULL
        )
        OR
        (
            order_status <> 'delivered'
            AND order_delivered_customer_date IS NOT NULL
        )
    ) AS has_status_timestamp_conflict,

    -- Metric-specific eligibility.
    (
        order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
    ) AS eligible_on_time_delivery,

    (
        order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_delivered_customer_date >= order_purchase_timestamp
    ) AS eligible_purchase_to_delivery,

    (
        order_status = 'delivered'
        AND order_approved_at IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL
        AND order_approved_at >= order_purchase_timestamp
        AND order_delivered_carrier_date >= order_approved_at
    ) AS eligible_seller_handling,

    (
        order_status = 'delivered'
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date IS NOT NULL
        AND order_delivered_carrier_date >= order_purchase_timestamp
        AND order_delivered_customer_date >= order_delivered_carrier_date
    ) AS eligible_carrier_transit

FROM raw.orders;