-- Seller rankings and contribution.
-- Volume is retained; rankings are descriptive, not intervention scores.

DROP TABLE IF EXISTS analysis.seller_rankings;
DROP TABLE IF EXISTS analysis.seller_contribution;
DROP TABLE IF EXISTS analysis.contribution_concentration;

CREATE TABLE analysis.seller_rankings AS
WITH recent AS (
    SELECT
        seller_id,
        MAX(seller_late_rate) FILTER (
            WHERE purchase_month = DATE '2018-08-01'
        ) AS late_rate_2018_08,
        MAX(delivery_eligible_seller_orders) FILTER (
            WHERE purchase_month = DATE '2018-08-01'
        ) AS eligible_2018_08,
        MAX(seller_late_rate) FILTER (
            WHERE purchase_month = DATE '2018-07-01'
        ) AS late_rate_2018_07,
        MAX(delivery_eligible_seller_orders) FILTER (
            WHERE purchase_month = DATE '2018-07-01'
        ) AS eligible_2018_07
    FROM analysis.seller_month
    WHERE purchase_month IN (DATE '2018-07-01', DATE '2018-08-01')
    GROUP BY seller_id
),
base AS (
    SELECT
        s.*,
        r.late_rate_2018_08,
        r.eligible_2018_08,
        r.late_rate_2018_07,
        r.eligible_2018_07,
        r.late_rate_2018_08 - r.late_rate_2018_07
            AS late_rate_pp_change_latest_comparable
    FROM metrics.kpi_sellers s
    LEFT JOIN recent r USING (seller_id)
)
SELECT
    seller_id,
    seller_order_volume,
    delivery_eligible_seller_orders,
    late_seller_orders,
    seller_late_rate,
    seller_late_contribution,
    seller_gmv,
    seller_late_gmv,
    reviewed_seller_orders,
    seller_negative_review_rate,
    RANK() OVER (
        ORDER BY seller_late_rate DESC NULLS LAST
    ) AS late_rate_rank,
    DENSE_RANK() OVER (
        ORDER BY seller_late_rate DESC NULLS LAST
    ) AS late_rate_dense_rank,
    ROW_NUMBER() OVER (
        ORDER BY seller_late_rate DESC NULLS LAST,
                 delivery_eligible_seller_orders DESC,
                 seller_id
    ) AS late_rate_row_number,
    CASE
        WHEN delivery_eligible_seller_orders > 0 THEN
            PERCENT_RANK() OVER (
                PARTITION BY (delivery_eligible_seller_orders > 0)
                ORDER BY seller_late_rate
            )
    END AS late_rate_percent_rank,
    RANK() OVER (
        ORDER BY seller_late_contribution DESC
    ) AS contribution_rank,
    RANK() OVER (
        ORDER BY delivery_eligible_seller_orders DESC
    ) AS eligible_volume_rank,
    RANK() OVER (
        ORDER BY seller_late_gmv DESC NULLS LAST
    ) AS late_gmv_rank,
    late_rate_2018_08,
    eligible_2018_08,
    late_rate_2018_07,
    eligible_2018_07,
    late_rate_pp_change_latest_comparable,
    RANK() OVER (
        ORDER BY late_rate_pp_change_latest_comparable DESC NULLS LAST
    ) AS recent_deterioration_rank,
    ROW_NUMBER() OVER (
        ORDER BY late_rate_pp_change_latest_comparable DESC NULLS LAST,
                 eligible_2018_08 DESC NULLS LAST,
                 seller_id
    ) AS recent_deterioration_row_number
FROM base;


CREATE TABLE analysis.seller_contribution AS
WITH ordered AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            ORDER BY late_seller_orders DESC,
                     seller_late_gmv DESC NULLS LAST,
                     seller_id
        ) AS contribution_row_number,
        RANK() OVER (
            ORDER BY late_seller_orders DESC
        ) AS late_units_rank
    FROM metrics.kpi_sellers s
),
cumulative AS (
    SELECT
        *,
        SUM(late_seller_orders) OVER (
            ORDER BY contribution_row_number
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_late_seller_orders,
        SUM(seller_late_gmv) OVER (
            ORDER BY contribution_row_number
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_late_gmv
    FROM ordered
)
SELECT
    seller_id,
    contribution_row_number,
    late_units_rank,
    delivery_eligible_seller_orders,
    late_seller_orders,
    seller_late_rate,
    seller_late_contribution,
    seller_gmv,
    seller_late_gmv,
    marketplace_late_seller_orders,
    cumulative_late_seller_orders,
    cumulative_late_seller_orders::NUMERIC
        / NULLIF(marketplace_late_seller_orders, 0)
        AS cumulative_late_contribution,
    cumulative_late_gmv,
    cumulative_late_gmv
        / NULLIF(SUM(seller_late_gmv) OVER (), 0)
        AS cumulative_late_gmv_share
FROM cumulative;


CREATE TABLE analysis.contribution_concentration AS
SELECT
    COUNT(*) FILTER (WHERE late_seller_orders > 0) AS sellers_with_late_orders,
    MIN(contribution_row_number) FILTER (
        WHERE cumulative_late_contribution >= 0.50
    ) AS sellers_to_50pct_late_units,
    MIN(contribution_row_number) FILTER (
        WHERE cumulative_late_contribution >= 0.80
    ) AS sellers_to_80pct_late_units,
    ROUND(SUM(seller_late_contribution), 10) AS contribution_sum,
    MAX(cumulative_late_seller_orders) AS marketplace_late_seller_orders
FROM analysis.seller_contribution;
