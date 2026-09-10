"""Validate seller concentration outputs against certified seller-order data."""

from decimal import Decimal

import pytest

from python.scripts.config import connect


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn, conn.cursor() as cur:
        yield cur


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def test_certified_late_units_and_contribution(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            SUM(late_seller_orders),
            MAX(marketplace_late_seller_orders),
            ROUND(SUM(seller_late_contribution), 10)
        FROM analysis.seller_prioritization
        """,
    )
    assert result == (6547, 6547, Decimal("1.0000000000"))


def test_rate_and_contribution_are_distinct(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE seller_late_rate = 1
                  AND delivery_eligible_seller_orders = 1
                  AND seller_late_contribution < 0.001
            ) > 0,
            COUNT(*) FILTER (
                WHERE contribution_row_number <= 10
                  AND seller_late_rate < marketplace_seller_late_rate
            ) > 0
        FROM analysis.seller_prioritization
        """,
    )
    assert result == (True, True)


def test_marketplace_excess_formula(cursor):
    expected_bad, excess_bad, sum_excess = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE ROUND(expected_late_marketplace::numeric, 8)
                   IS DISTINCT FROM ROUND(
                       delivery_eligible_seller_orders
                       * marketplace_seller_late_rate, 8
                   )
            ),
            COUNT(*) FILTER (
                WHERE ROUND(excess_late_marketplace::numeric, 8)
                   IS DISTINCT FROM ROUND(
                       late_seller_orders - expected_late_marketplace, 8
                   )
            ),
            ROUND(SUM(excess_late_marketplace)::numeric, 6)
        FROM analysis.seller_prioritization
        """,
    )
    assert (expected_bad, excess_bad, sum_excess) == (
        0,
        0,
        Decimal("0.000000"),
    )


def test_selected_sellers_match_source(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analysis.seller_prioritization p
        JOIN (
            SELECT
                seller_id,
                COUNT(*) FILTER (WHERE is_delivery_performance_eligible) AS eligible,
                COUNT(*) FILTER (WHERE is_late) AS late
            FROM metrics.kpi_seller_orders
            GROUP BY seller_id
        ) s USING (seller_id)
        WHERE p.seller_id IN (
            '4a3ca9315b744ce9f8e9374361493884',
            '06a2c3af7b3aee5d69171b0e14f0ee87',
            '6560211a19b47992c3666cc44a7e94c0'
        )
          AND (
              p.delivery_eligible_seller_orders IS DISTINCT FROM s.eligible
              OR p.late_seller_orders IS DISTINCT FROM s.late
          )
        """,
    )
    assert mismatches == 0


def test_seller_gmv_matches_item_price(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analysis.seller_prioritization p
        JOIN (
            SELECT seller_id, ROUND(SUM(price)::numeric, 2) AS seller_gmv
            FROM analytics.fact_order_items
            GROUP BY seller_id
        ) i USING (seller_id)
        WHERE ROUND(p.seller_gmv::numeric, 2) IS DISTINCT FROM i.seller_gmv
        """,
    )
    assert mismatches == 0


def test_watchlist_is_traceable(cursor):
    n_rows, missing_reason, outside_rule = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(*) FILTER (WHERE COALESCE(watchlist_reasons, '') = ''),
            COUNT(*) FILTER (
                WHERE NOT is_high_excess
                  AND NOT is_high_rate_high_volume
                  AND NOT is_recently_deteriorating
            )
        FROM analysis.seller_watchlist
        """,
    )
    assert n_rows > 0
    assert missing_reason == 0
    assert outside_rule == 0


def test_low_volume_noise_stays_off_watchlist(cursor):
    high_rate_low_volume, watchlist_low_volume = fetch_one(
        cursor,
        """
        SELECT
            EXISTS (
                SELECT 1
                FROM analysis.seller_prioritization
                WHERE is_high_rate_low_volume
            ),
            (
                SELECT COUNT(*)
                FROM analysis.seller_watchlist
                WHERE delivery_eligible_seller_orders < 100
                  AND NOT is_recently_deteriorating
            )
        """,
    )
    assert high_rate_low_volume
    assert watchlist_low_volume == 0
