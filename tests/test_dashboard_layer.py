"""Validate dashboard views against certified metric and analysis outputs."""

from decimal import Decimal

import pytest

from python.scripts.config import connect


SELECTED_SELLER = "4a3ca9315b744ce9f8e9374361493884"


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn, conn.cursor() as cur:
        yield cur


def fetch_one(cursor, sql, params=None):
    cursor.execute(sql, params)
    return cursor.fetchone()


def test_executive_kpis(cursor):
    full = fetch_one(
        cursor,
        """
        SELECT
            d.all_orders,
            d.delivery_performance_eligible,
            d.on_time_count,
            d.late_count,
            d.gmv,
            d.late_gmv,
            d.negative_review_count,
            d.watchlist_sellers,
            d.watchlist_late_seller_orders,
            d.high_excess_sellers
        FROM dashboard.executive_overview d
        WHERE d.reporting_scope = 'full_extract'
        """,
    )
    source = fetch_one(
        cursor,
        """
        SELECT
            m.all_orders,
            m.delivery_performance_eligible,
            m.on_time_count,
            m.late_count,
            m.gmv,
            m.late_gmv,
            m.negative_review_count,
            COUNT(w.seller_id)::integer,
            SUM(w.late_seller_orders)::integer,
            COUNT(w.seller_id) FILTER (WHERE w.is_high_excess)::integer
        FROM metrics.kpi_marketplace m
        CROSS JOIN analysis.seller_watchlist w
        GROUP BY
            m.all_orders,
            m.delivery_performance_eligible,
            m.on_time_count,
            m.late_count,
            m.gmv,
            m.late_gmv,
            m.negative_review_count
        """,
    )
    comparable = fetch_one(
        cursor,
        """
        SELECT
            delivery_performance_eligible,
            late_count,
            late_gmv
        FROM dashboard.executive_overview
        WHERE reporting_scope = 'comparable_trend_window'
        """,
    )

    assert full == source
    assert full[:4] == (99441, 96470, 89936, 6534)
    assert full[7:] == (25, 1408, 14)
    assert comparable == (95453, 6509, Decimal("982502.52"))


def test_fulfillment_trends(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT d.purchase_month),
            COUNT(*) FILTER (
                WHERE d.late_count IS DISTINCT FROM t.late_count
                   OR d.late_count IS DISTINCT FROM f.late_count
            ),
            MAX(d.late_count) FILTER (WHERE d.purchase_month = DATE '2017-11-01'),
            MAX(d.late_count) FILTER (WHERE d.purchase_month = DATE '2018-02-01'),
            MAX(d.late_count) FILTER (WHERE d.purchase_month = DATE '2018-03-01'),
            MAX(d.late_count) FILTER (WHERE d.purchase_month = DATE '2018-08-01')
        FROM dashboard.fulfillment_trends d
        JOIN analysis.marketplace_month_trend t USING (purchase_month)
        JOIN analysis.fulfillment_month f USING (purchase_month)
        """,
    )

    assert result == (26, 26, 0, 904, 926, 1328, 393)


def test_seller_performance(cursor):
    rows, distinct_sellers, extra, missing, mismatch = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM dashboard.seller_performance),
            (SELECT COUNT(DISTINCT seller_id) FROM dashboard.seller_performance),
            (
                SELECT COUNT(*)
                FROM dashboard.seller_performance d
                LEFT JOIN analysis.seller_prioritization p USING (seller_id)
                WHERE p.seller_id IS NULL
            ),
            (
                SELECT COUNT(*)
                FROM analysis.seller_prioritization p
                LEFT JOIN dashboard.seller_performance d USING (seller_id)
                WHERE d.seller_id IS NULL
            ),
            (
                SELECT COUNT(*)
                FROM dashboard.seller_performance d
                JOIN analysis.seller_prioritization p USING (seller_id)
                WHERE ROUND(d.excess_late_marketplace::numeric, 8)
                   IS DISTINCT FROM ROUND(p.excess_late_marketplace::numeric, 8)
            )
        """,
    )
    watchlist = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (WHERE is_on_watchlist),
            COUNT(*) FILTER (WHERE is_high_excess),
            COUNT(*) FILTER (
                WHERE is_on_watchlist AND COALESCE(watchlist_reasons, '') = ''
            ),
            COUNT(*) FILTER (
                WHERE is_high_excess
                  AND investigation_queue <> 'investigate_high_excess'
            )
        FROM dashboard.seller_performance
        """,
    )
    selected = fetch_one(
        cursor,
        """
        SELECT
            delivery_eligible_seller_orders,
            late_seller_orders,
            ROUND(seller_late_rate, 10),
            ROUND(excess_late_marketplace, 1),
            is_on_watchlist,
            is_high_excess
        FROM dashboard.seller_performance
        WHERE seller_id = %s
        """,
        (SELECTED_SELLER,),
    )

    assert (rows, distinct_sellers, extra, missing, mismatch) == (3095, 3095, 0, 0, 0)
    assert watchlist == (25, 14, 0, 0)
    assert selected == (
        1772,
        172,
        Decimal("0.0970654628"),
        Decimal("53.4"),
        True,
        True,
    )


def test_category_reconciliation(cursor):
    category_gmv, marketplace_gmv, category_late, marketplace_late = fetch_one(
        cursor,
        """
        SELECT
            (
                SELECT ROUND(SUM(gmv)::numeric, 2)
                FROM dashboard.category_performance
                WHERE reporting_scope = 'full_extract'
            ),
            (SELECT gmv FROM metrics.kpi_marketplace),
            (
                SELECT SUM(late_units)
                FROM dashboard.category_performance
                WHERE reporting_scope = 'full_extract'
            ),
            (
                SELECT marketplace_late_seller_orders
                FROM metrics.kpi_sellers
                LIMIT 1
            )
        """,
    )

    assert category_gmv == marketplace_gmv == Decimal("13591643.70")
    assert marketplace_late == 6547
    assert category_late != marketplace_late


def test_geography(cursor):
    dashboard_rj = fetch_one(
        cursor,
        """
        SELECT eligible_orders, late_orders, ROUND(late_rate, 10)
        FROM dashboard.geography_performance
        WHERE reporting_scope = 'comparable_trend_window'
          AND customer_state = 'RJ'
        """,
    )
    source_rj = fetch_one(
        cursor,
        """
        SELECT eligible_units, late_units, ROUND(late_rate, 10)
        FROM analysis.segment_fulfillment_performance
        WHERE segment_type = 'customer_state'
          AND segment_key = 'RJ'
        """,
    )
    feb_rj, aug_sp = fetch_one(
        cursor,
        """
        SELECT
            MAX(late_orders) FILTER (
                WHERE customer_state = 'RJ'
                  AND purchase_month = DATE '2018-02-01'
            ),
            MAX(late_orders) FILTER (
                WHERE customer_state = 'SP'
                  AND purchase_month = DATE '2018-08-01'
            )
        FROM dashboard.geography_month
        """,
    )

    assert dashboard_rj == source_rj == (12219, 1492, Decimal("0.1221049186"))
    assert (feb_rj, aug_sp) == (299, 285)


def test_latest_rolling_windows(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            purchase_date,
            eligible_count_30d,
            late_count_30d,
            eligible_count_90d,
            late_count_90d
        FROM dashboard.marketplace_rolling
        WHERE is_full_30d_window
          AND is_full_90d_window
          AND is_comparable_trend_window
        ORDER BY purchase_date DESC
        LIMIT 1
        """,
    )

    as_of, eligible_30, late_30, eligible_90, late_90 = result
    assert as_of.isoformat() == "2018-08-31"
    assert (eligible_30, late_30, eligible_90, late_90) == (6045, 364, 18278, 669)


def test_customer_experience(cursor):
    early, late = fetch_one(
        cursor,
        """
        SELECT
            MAX(ROUND(negative_review_rate, 10))
                FILTER (WHERE delivery_class = 'early'),
            MAX(ROUND(negative_review_rate, 10))
                FILTER (WHERE delivery_class = 'late')
        FROM dashboard.delivery_review
        """,
    )

    assert early == Decimal("0.0911092508")
    assert late == Decimal("0.6234342794")


def test_dashboard_views_exist(cursor):
    (view_count,) = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM information_schema.views
        WHERE table_schema = 'dashboard'
          AND table_name = ANY (ARRAY[
              'executive_overview',
              'fulfillment_trends',
              'fulfillment_components',
              'marketplace_rolling',
              'delivery_review',
              'delay_band_reviews',
              'seller_performance',
              'seller_month',
              'category_performance',
              'geography_performance',
              'geography_month'
          ])
        """,
    )

    assert view_count == 11
