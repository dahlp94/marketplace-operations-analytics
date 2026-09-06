-- Trace representative source cases through the analytical model.

SELECT
    'simple_1_1_1' AS case_name,
    f.order_id,
    f.order_status,
    f.n_items,
    f.n_payment_rows,
    f.n_review_rows,
    f.n_sellers,
    f.merchandise_value,
    f.item_side_value,
    f.collected_payment,
    f.order_review_score
FROM analytics.fact_orders f
WHERE f.order_id = '3b697a20d9e427646d92567910af6d57';


SELECT
    'multi_item_single_payment' AS case_name,
    f.order_id,
    f.n_items,
    f.n_payment_rows,
    f.item_side_value,
    f.collected_payment,
    f.monetary_diff_gt_tolerance
FROM analytics.fact_orders f
WHERE f.order_id = '00143d0f86d6fbd9f9b38ab440ac16f5';


SELECT
    'single_item_multi_payment' AS case_name,
    f.order_id,
    f.n_items,
    f.n_payment_rows,
    f.item_side_value,
    f.collected_payment
FROM analytics.fact_orders f
WHERE f.order_id = '009ac365164f8e06f59d18a08045f6c4';


SELECT
    'multi_seller_order' AS case_name,
    i.order_id,
    i.order_item_id,
    i.seller_id,
    i.price
FROM analytics.fact_order_items i
WHERE i.order_id = '002f98c0f7efd42638ed6100ca699b42'
ORDER BY i.order_item_id;


SELECT
    'order_without_payments' AS case_name,
    f.order_id,
    f.order_status,
    f.n_items,
    f.n_payment_rows,
    f.merchandise_value,
    f.collected_payment
FROM analytics.fact_orders f
WHERE f.order_id = 'bfbd0f9bdef84302105ad712db648a6c';


SELECT
    'reused_review_id' AS case_name,
    r.review_id,
    r.order_id,
    r.review_score,
    r.review_id_reused
FROM analytics.fact_reviews r
WHERE r.review_id = '08528f70f579f0c830189efc523d2182'
ORDER BY r.order_id;