-- Keep review rows and flag reused review identifiers.

DROP TABLE IF EXISTS stg.order_reviews;

CREATE TABLE stg.order_reviews AS
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    COUNT(*) OVER (PARTITION BY review_id) > 1 AS review_id_reused
FROM raw.order_reviews;
