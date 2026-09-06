-- Trace a small set of known edge cases from raw source data to analytics.

WITH sample AS (
    SELECT *
    FROM (
        VALUES
            ('multi_item', '00143d0f86d6fbd9f9b38ab440ac16f5'),
            ('multi_payment', '009ac365164f8e06f59d18a08045f6c4'),
            ('multi_seller', '002f98c0f7efd42638ed6100ca699b42'),
            ('no_payment', 'bfbd0f9bdef84302105ad712db648a6c'),
            ('monetary_mismatch', 'ce6d150fb29ada17d2082f4847107665')
    ) AS t(case_name, order_id)
)
SELECT
    s.case_name,
    s.order_id,

    (SELECT COUNT(*) FROM raw.orders r
     WHERE r.order_id = s.order_id) AS raw_orders,

    (SELECT COUNT(*) FROM analytics.fact_orders a
     WHERE a.order_id = s.order_id) AS fact_orders,

    (SELECT COUNT(*) FROM raw.order_items r
     WHERE r.order_id = s.order_id) AS raw_items,

    (SELECT COUNT(*) FROM analytics.fact_order_items a
     WHERE a.order_id = s.order_id) AS fact_items,

    (SELECT COUNT(*) FROM raw.order_payments r
     WHERE r.order_id = s.order_id) AS raw_payments,

    (SELECT COUNT(*) FROM analytics.fact_payments a
     WHERE a.order_id = s.order_id) AS fact_payments
FROM sample s
ORDER BY s.case_name;


-- Reused review IDs remain visible and flagged.

SELECT
    r.review_id,
    r.order_id,
    r.review_score AS raw_score,
    a.review_score AS analytical_score,
    a.review_id_reused
FROM raw.order_reviews r
JOIN analytics.fact_reviews a
    ON a.review_id = r.review_id
   AND a.order_id = r.order_id
WHERE r.review_id = '08528f70f579f0c830189efc523d2182'
ORDER BY r.order_id;
