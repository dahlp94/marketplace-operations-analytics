"""Independent certification checks for metric and analysis layers."""

import pytest

from python.scripts.config import connect


DELIVERY_ELIGIBLE = """
    order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
"""


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn:
        with conn.cursor() as cur:
            yield cur


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def test_marketplace_kpis_and_reviews(cursor):
    checks = fetch_one(
        cursor,
        f"""
        WITH source AS (
            SELECT
                COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered,
                COUNT(*) FILTER (WHERE {DELIVERY_ELIGIBLE}) AS eligible,
                COUNT(*) FILTER (
                    WHERE {DELIVERY_ELIGIBLE}
                      AND order_delivered_customer_date::date
                          <= order_estimated_delivery_date::date
                ) AS on_time,
                COUNT(*) FILTER (
                    WHERE {DELIVERY_ELIGIBLE}
                      AND order_delivered_customer_date::date
                          > order_estimated_delivery_date::date
                ) AS late,
                ROUND(SUM(merchandise_value), 2) AS gmv,
                COUNT(*) FILTER (WHERE n_usable_review_rows > 0) AS reviewed,
                COUNT(*) FILTER (
                    WHERE n_usable_review_rows > 0
                      AND order_review_score <= 2
                ) AS negative
            FROM analytics.fact_orders
        )
        SELECT
            s.delivered = k.delivered_orders,
            s.eligible = k.delivery_performance_eligible,
            s.on_time = k.on_time_count,
            s.late = k.late_count,
            s.gmv = k.gmv,
            s.reviewed = k.reviewed_orders,
            s.negative = k.negative_review_count,
            NOT EXISTS (
                SELECT 1
                FROM metrics.kpi_orders
                WHERE NOT has_usable_review
                  AND is_negative_review IS NOT NULL
            )
        FROM source s
        CROSS JOIN metrics.kpi_marketplace k
        """,
    )

    assert all(checks)


def test_seller_and_category_reconciliation(cursor):
    checks = fetch_one(
        cursor,
        f"""
        WITH seller_orders AS (
            SELECT seller_id, order_id, ROUND(SUM(price), 2) AS gmv
            FROM analytics.fact_order_items
            GROUP BY seller_id, order_id
        ),
        late AS (
            SELECT order_id, n_sellers
            FROM analytics.fact_orders
            WHERE {DELIVERY_ELIGIBLE}
              AND order_delivered_customer_date::date
                  > order_estimated_delivery_date::date
        ),
        seller_gmv AS (
            SELECT seller_id, ROUND(SUM(price), 2) AS gmv
            FROM analytics.fact_order_items
            GROUP BY seller_id
        )
        SELECT
            (SELECT COUNT(*) FROM seller_orders JOIN late USING (order_id))
                = (SELECT SUM(late_seller_orders) FROM metrics.kpi_sellers),
            (SELECT COUNT(*) FROM seller_orders JOIN late USING (order_id))
                = (SELECT COUNT(*) + COALESCE(
                        SUM(n_sellers - 1) FILTER (WHERE n_sellers > 1), 0
                    )
                   FROM late),
            ROUND((SELECT SUM(seller_late_contribution)
                   FROM metrics.kpi_sellers), 10) = 1,
            NOT EXISTS (
                SELECT 1
                FROM seller_gmv i
                JOIN metrics.kpi_sellers k USING (seller_id)
                WHERE i.gmv IS DISTINCT FROM ROUND(k.seller_gmv, 2)
            ),
            ROUND((SELECT SUM(seller_category_gmv)
                   FROM analysis.seller_category), 2)
                = (SELECT gmv FROM metrics.kpi_marketplace),
            (SELECT SUM(late_seller_orders)
             FROM analysis.seller_category)
                <> (SELECT SUM(late_seller_orders)
                    FROM metrics.kpi_sellers)
        """,
    )

    assert all(checks)


def test_geography_reconciles(cursor):
    checks = fetch_one(
        cursor,
        """
        SELECT
            (SELECT SUM(all_orders)
             FROM analysis.customer_state_performance)
                = (SELECT COUNT(*) FROM metrics.kpi_orders),
            (SELECT ROUND(SUM(gmv), 2)
             FROM analysis.customer_state_performance)
                = (SELECT gmv FROM metrics.kpi_marketplace),
            (SELECT SUM(seller_order_volume)
             FROM analysis.seller_state_performance)
                = (SELECT COUNT(*) FROM metrics.kpi_seller_orders),
            (SELECT COUNT(*) FROM metrics.kpi_orders)
                = (
                    SELECT COUNT(*)
                    FROM metrics.kpi_orders o
                    JOIN analytics.dim_customer c USING (customer_id)
                    LEFT JOIN analytics.dim_geography g
                        ON g.zip_code_prefix = c.zip_code_prefix
                )
        """,
    )

    assert all(checks)


def test_windows_and_lag(cursor):
    checks = fetch_one(
        cursor,
        f"""
        WITH expected AS (
            SELECT
                COUNT(*) FILTER (
                    WHERE purchase_date >= DATE '2018-05-15' - 29
                      AND {DELIVERY_ELIGIBLE}
                      AND order_delivered_customer_date::date
                          > order_estimated_delivery_date::date
                ) AS late_30d,
                COUNT(*) FILTER (
                    WHERE purchase_date >= DATE '2018-05-15' - 29
                      AND {DELIVERY_ELIGIBLE}
                ) AS eligible_30d,
                COUNT(*) FILTER (
                    WHERE {DELIVERY_ELIGIBLE}
                      AND order_delivered_customer_date::date
                          > order_estimated_delivery_date::date
                ) AS late_90d,
                COUNT(*) FILTER (WHERE {DELIVERY_ELIGIBLE}) AS eligible_90d
            FROM analytics.fact_orders
            WHERE purchase_date BETWEEN DATE '2018-05-15' - 89
                                    AND DATE '2018-05-15'
        ),
        rates AS (
            SELECT
                MAX(late_delivery_rate) FILTER (
                    WHERE purchase_month = DATE '2017-02-01'
                ) AS feb_rate,
                MAX(late_delivery_rate) FILTER (
                    WHERE purchase_month = DATE '2017-03-01'
                ) AS mar_rate
            FROM metrics.kpi_marketplace_month
        )
        SELECT
            e.late_30d = d.late_count_30d
                AND e.eligible_30d = d.eligible_count_30d,
            e.late_90d = d.late_count_90d
                AND e.eligible_90d = d.eligible_count_90d,
            feb.comparable_prior_late_delivery_rate IS NULL,
            ROUND(r.mar_rate - r.feb_rate, 10)
                = ROUND(mar.late_rate_pp_change, 10)
        FROM expected e
        JOIN analysis.marketplace_day d
          ON d.purchase_date = DATE '2018-05-15'
        JOIN analysis.marketplace_month_trend feb
          ON feb.purchase_month = DATE '2017-02-01'
        JOIN analysis.marketplace_month_trend mar
          ON mar.purchase_month = DATE '2017-03-01'
        CROSS JOIN rates r
        """,
    )

    assert all(checks)


def test_repeat_sequence(cursor):
    mismatches, repeat_matches = fetch_one(
        cursor,
        """
        WITH independent AS (
            SELECT
                o.order_id,
                ROW_NUMBER() OVER (
                    PARTITION BY c.customer_unique_id
                    ORDER BY o.order_purchase_timestamp, o.order_id
                ) AS sequence
            FROM analytics.fact_orders o
            JOIN analytics.dim_customer c USING (customer_id)
        )
        SELECT
            COUNT(*) FILTER (
                WHERE i.sequence IS DISTINCT FROM k.customer_order_sequence
                   OR (i.sequence > 1) IS DISTINCT FROM k.is_repeat_order
            ),
            COUNT(*) FILTER (WHERE i.sequence > 1)
                = (SELECT repeat_orders FROM metrics.kpi_marketplace)
        FROM independent i
        JOIN metrics.kpi_orders k USING (order_id)
        """,
    )

    assert mismatches == 0
    assert repeat_matches


def test_ranking_and_low_volume(cursor):
    broken_ties, duplicate_rows, low_volume, rank_mismatches = fetch_one(
        cursor,
        """
        WITH expected AS (
            SELECT
                seller_id,
                RANK() OVER (
                    ORDER BY seller_late_rate DESC NULLS LAST
                ) AS expected_rank
            FROM metrics.kpi_sellers
        )
        SELECT
            (
                SELECT COUNT(*)
                FROM (
                    SELECT seller_late_rate
                    FROM analysis.seller_rankings
                    WHERE seller_late_rate IS NOT NULL
                    GROUP BY seller_late_rate
                    HAVING COUNT(*) > 1
                       AND COUNT(DISTINCT late_rate_rank) > 1
                ) x
            ),
            COUNT(*) - COUNT(DISTINCT late_rate_row_number),
            COUNT(*) FILTER (WHERE delivery_eligible_seller_orders = 1),
            (
                SELECT COUNT(*)
                FROM expected e
                JOIN analysis.seller_rankings a USING (seller_id)
                WHERE e.expected_rank IS DISTINCT FROM a.late_rate_rank
            )
        FROM analysis.seller_rankings
        """,
    )

    assert broken_ties == 0
    assert duplicate_rows == 0
    assert low_volume > 0
    assert rank_mismatches == 0


def test_structural_qa(cursor):
    checks = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) - COUNT(DISTINCT order_id)
             FROM metrics.kpi_orders) = 0,
            (SELECT COUNT(*) - COUNT(DISTINCT (seller_id, order_id))
             FROM metrics.kpi_seller_orders) = 0,
            (SELECT COUNT(*) - COUNT(DISTINCT (seller_id, purchase_date))
             FROM analysis.seller_day_rolling) = 0,
            NOT EXISTS (
                SELECT 1
                FROM metrics.kpi_sellers
                WHERE seller_late_rate NOT BETWEEN 0 AND 1
                   OR seller_late_contribution NOT BETWEEN 0 AND 1
            ),
            ROUND((SELECT SUM(seller_late_contribution)
                   FROM analysis.seller_contribution), 10) = 1,
            (SELECT MAX(cumulative_late_contribution)
             FROM analysis.seller_contribution) = 1
        """,
    )

    assert all(checks)
