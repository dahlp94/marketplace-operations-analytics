-- One row per review-order pair.
-- Reused review IDs remain visible through the quality flag.

DROP TABLE IF EXISTS analytics.fact_reviews;

CREATE TABLE analytics.fact_reviews AS
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    review_id_reused
FROM stg.order_reviews;
