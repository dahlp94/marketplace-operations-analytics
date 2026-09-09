"""Structural checks for the analysis layer."""

import pytest

from python.scripts.config import connect


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn:
        with conn.cursor() as cur:
            yield cur


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def test_reporting_periods(cursor):
    checks = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) = 26,
            COUNT(*) FILTER (WHERE is_comparable_trend_window) = 19,
            COUNT(*) FILTER (WHERE NOT is_comparable_trend_window) > 0
        FROM analysis.reporting_month
        """,
    )
    assert all(checks)


def test_lag_logic(cursor):
    calendar_prior_exists, comparable_prior_null, changes_match = fetch_one(
        cursor,
        """
        WITH rates AS (
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
            feb.prior_late_delivery_rate IS NOT NULL,
            feb.comparable_prior_late_delivery_rate IS NULL,
            ROUND(r.mar_rate - r.feb_rate, 10)
                = ROUND(mar.late_rate_pp_change, 10)
            AND ROUND(r.mar_rate - r.feb_rate, 10)
                = ROUND(mar.comparable_late_rate_pp_change, 10)
        FROM rates r
        CROSS JOIN analysis.marketplace_month_trend feb
        CROSS JOIN analysis.marketplace_month_trend mar
        WHERE feb.purchase_month = DATE '2017-02-01'
          AND mar.purchase_month = DATE '2017-03-01'
        """,
    )

    assert calendar_prior_exists
    assert comparable_prior_null
    assert changes_match


def test_rolling_windows(cursor):
    matches_30d, matches_90d, full_windows = fetch_one(
        cursor,
        """
        WITH expected AS (
            SELECT
                COUNT(*) FILTER (
                    WHERE purchase_date >= DATE '2018-05-15' - 29
                      AND is_late
                ) AS late_30d,
                COUNT(*) FILTER (
                    WHERE purchase_date >= DATE '2018-05-15' - 29
                      AND is_delivery_performance_eligible
                ) AS eligible_30d,
                COUNT(*) FILTER (WHERE is_late) AS late_90d,
                COUNT(*) FILTER (
                    WHERE is_delivery_performance_eligible
                ) AS eligible_90d
            FROM metrics.kpi_orders
            WHERE purchase_date BETWEEN DATE '2018-05-15' - 89
                                    AND DATE '2018-05-15'
        )
        SELECT
            e.late_30d = a.late_count_30d
                AND e.eligible_30d = a.eligible_count_30d,
            e.late_90d = a.late_count_90d
                AND e.eligible_90d = a.eligible_count_90d,
            a.is_full_30d_window AND a.is_full_90d_window
        FROM expected e
        JOIN analysis.marketplace_day a
          ON a.purchase_date = DATE '2018-05-15'
        """,
    )

    assert matches_30d
    assert matches_90d
    assert full_windows


def test_ranking_semantics(cursor):
    broken_ties, duplicate_rows = fetch_one(
        cursor,
        """
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
            COUNT(*) - COUNT(DISTINCT late_rate_row_number)
        FROM analysis.seller_rankings
        """,
    )

    assert broken_ties == 0
    assert duplicate_rows == 0


def test_contribution_reconciles(cursor):
    sums_to_one, units_match, sellers_match, monotonic = fetch_one(
        cursor,
        """
        WITH ordered AS (
            SELECT
                cumulative_late_contribution
                - LAG(cumulative_late_contribution) OVER (
                    ORDER BY contribution_row_number
                ) AS step
            FROM analysis.seller_contribution
        )
        SELECT
            ROUND(SUM(c.seller_late_contribution), 10) = 1,
            SUM(c.late_seller_orders)
                = (SELECT SUM(late_seller_orders) FROM metrics.kpi_sellers),
            COUNT(*)
                = (SELECT COUNT(*) FROM metrics.kpi_sellers),
            (SELECT COUNT(*) FROM ordered WHERE step < 0) = 0
        FROM analysis.seller_contribution c
        """,
    )

    assert sums_to_one
    assert units_match
    assert sellers_match
    assert monotonic


def test_category_reconciliation(cursor):
    gmv_matches, has_multi_category_sellers = fetch_one(
        cursor,
        """
        SELECT
            ROUND(SUM(seller_category_gmv), 2)
                = (SELECT ROUND(SUM(gmv), 2) FROM metrics.kpi_orders),
            EXISTS (
                SELECT 1
                FROM analysis.seller_category
                GROUP BY seller_id
                HAVING COUNT(*) > 1
            )
        FROM analysis.seller_category
        """,
    )

    assert gmv_matches
    assert has_multi_category_sellers


def test_geography_and_repeat_reconcile(cursor):
    orders_match, gmv_matches, repeat_matches = fetch_one(
        cursor,
        """
        SELECT
            (SELECT SUM(all_orders) FROM analysis.customer_state_performance)
                = (SELECT COUNT(*) FROM metrics.kpi_orders),
            (SELECT ROUND(SUM(gmv), 2)
             FROM analysis.customer_state_performance)
                = (SELECT ROUND(SUM(gmv), 2) FROM metrics.kpi_orders),
            (SELECT SUM(all_orders) FILTER (WHERE is_repeat_order)
             FROM analysis.repeat_order_performance)
                = (SELECT COUNT(*)
                   FROM metrics.kpi_orders
                   WHERE is_repeat_order)
        """,
    )

    assert orders_match
    assert gmv_matches
    assert repeat_matches


def test_low_volume_sellers_remain_visible(cursor):
    has_one_order_sellers, invalid_rates = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (WHERE delivery_eligible_seller_orders = 1) > 0,
            COUNT(*) FILTER (
                WHERE delivery_eligible_seller_orders = 0
                  AND seller_late_rate IS NOT NULL
            )
        FROM analysis.seller_rankings
        """,
    )

    assert has_one_order_sellers
    assert invalid_rates == 0
