-- Investigate review identifiers and multiple-review orders.
-- Source grain and basic review cardinality are already covered by the source audit.

-- Reused review_id values across orders.
WITH reused AS (
    SELECT
        review_id,
        COUNT(*) AS n_rows,
        COUNT(DISTINCT order_id) AS n_orders
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS reused_review_ids,
    SUM(n_rows) AS review_rows_involved,
    SUM(n_orders) AS orders_involved,
    MAX(n_rows) AS max_rows_per_review_id
FROM reused;

-- Do reused review IDs carry the same review payload?
WITH reused_ids AS (
    SELECT review_id
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
),
payloads AS (
    SELECT
        r.review_id,
        COUNT(DISTINCT (
            r.review_score,
            r.review_comment_title,
            r.review_comment_message,
            r.review_creation_date,
            r.review_answer_timestamp
        )) AS n_payloads
    FROM raw.order_reviews r
    JOIN reused_ids x
        ON x.review_id = r.review_id
    GROUP BY r.review_id
)
SELECT
    COUNT(*) AS reused_review_ids,
    COUNT(*) FILTER (WHERE n_payloads = 1) AS same_payload,
    COUNT(*) FILTER (WHERE n_payloads > 1) AS different_payload
FROM payloads;

-- Multiple reviews on the same order: do scores agree?
WITH multi_review_orders AS (
    SELECT
        order_id,
        COUNT(*) AS n_reviews,
        COUNT(DISTINCT review_score) AS n_scores
    FROM raw.order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS multi_review_orders,
    COUNT(*) FILTER (WHERE n_scores = 1) AS same_score,
    COUNT(*) FILTER (WHERE n_scores > 1) AS different_scores,
    MAX(n_reviews) AS max_reviews_per_order
FROM multi_review_orders;

-- Sample reused review IDs for manual inspection.
SELECT
    review_id,
    order_id,
    review_score,
    review_creation_date,
    review_answer_timestamp,
    LEFT(COALESCE(review_comment_message, ''), 80) AS comment_preview
FROM raw.order_reviews
WHERE review_id IN (
    SELECT review_id
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
ORDER BY review_id, order_id
LIMIT 20;
