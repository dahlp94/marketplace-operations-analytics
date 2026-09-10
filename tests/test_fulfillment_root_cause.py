"""Validate fulfillment root-cause outputs against certified KPI fields."""

from datetime import date

import pytest

from python.scripts.config import connect


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn, conn.cursor() as cur:
        yield cur


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def test_comparable_window_definition(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT MIN(purchase_month), MAX(purchase_month), COUNT(*)
        FROM analysis.fulfillment_month
        WHERE is_comparable_trend_window
        """,
    )
    assert result == (date(2017, 2, 1), date(2018, 8, 1), 19)


def test_monthly_late_metrics_match_certified_trend(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analysis.fulfillment_month f
        JOIN analysis.marketplace_month_trend t USING (purchase_month)
        WHERE f.late_count IS DISTINCT FROM t.late_count
           OR f.delivery_performance_eligible
              IS DISTINCT FROM t.delivery_performance_eligible
           OR ROUND(f.late_delivery_rate::numeric, 10)
              IS DISTINCT FROM ROUND(t.late_delivery_rate::numeric, 10)
        """,
    )
    assert mismatches == 0


def test_monthly_durations_match_certified_marketplace(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analysis.fulfillment_month f
        JOIN metrics.kpi_marketplace_month m USING (purchase_month)
        WHERE ROUND(f.avg_seller_handling_days::numeric, 10)
              IS DISTINCT FROM ROUND(m.avg_seller_handling_days::numeric, 10)
           OR ROUND(f.avg_carrier_transit_days::numeric, 10)
              IS DISTINCT FROM ROUND(m.avg_carrier_transit_days::numeric, 10)
           OR ROUND(f.avg_promised_window_days::numeric, 10)
              IS DISTINCT FROM ROUND(m.avg_promised_window_days::numeric, 10)
           OR ROUND(f.avg_purchase_to_delivery_days::numeric, 10)
              IS DISTINCT FROM ROUND(m.avg_purchase_to_delivery_days::numeric, 10)
        """,
    )
    assert mismatches == 0


def test_comparable_window_reconciles_to_kpi_orders(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (WHERE is_delivery_performance_eligible),
            COUNT(*) FILTER (WHERE is_late),
            (
                SELECT SUM(delivery_performance_eligible)
                FROM analysis.fulfillment_month
                WHERE is_comparable_trend_window
            ),
            (
                SELECT SUM(late_count)
                FROM analysis.fulfillment_month
                WHERE is_comparable_trend_window
            )
        FROM metrics.kpi_orders
        WHERE is_comparable_trend_window
        """,
    )
    assert result == (95453, 6509, 95453, 6509)


def test_decomposition_matches_certified_delivery_class(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analysis.fulfillment_decomposition d
        JOIN (
            SELECT
                delivery_class,
                COUNT(*)::integer AS eligible_orders
            FROM metrics.kpi_orders
            WHERE is_comparable_trend_window
              AND is_delivery_performance_eligible
            GROUP BY delivery_class
        ) k USING (delivery_class)
        WHERE d.analysis_period = 'comparable_trend_window'
          AND d.eligible_orders IS DISTINCT FROM k.eligible_orders
        """,
    )
    assert mismatches == 0


def test_components_are_separately_populated(cursor):
    handling, transit, promise = fetch_one(
        cursor,
        """
        SELECT
            median_seller_handling_days,
            median_carrier_transit_days,
            median_promised_window_days
        FROM analysis.fulfillment_decomposition
        WHERE analysis_period = 'comparable_trend_window'
          AND delivery_class = 'late'
        """,
    )
    assert None not in (handling, transit, promise)
    assert transit > handling


def test_low_sample_segments_are_flagged(cursor):
    mismatches, low_count = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE is_low_sample IS DISTINCT FROM (eligible_units < 100)
            ),
            COUNT(*) FILTER (WHERE is_low_sample)
        FROM analysis.segment_fulfillment_performance
        """,
    )
    assert mismatches == 0
    assert low_count > 0


def test_selected_order_durations_match_fact_orders(cursor):
    n_rows, handling_bad, transit_bad, delay_bad = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(*) FILTER (
                WHERE ROUND(o.seller_handling_days::numeric, 10)
                      IS DISTINCT FROM ROUND((
                          EXTRACT(EPOCH FROM (
                              f.order_delivered_carrier_date - f.order_approved_at
                          )) / 86400.0
                      )::numeric, 10)
            ),
            COUNT(*) FILTER (
                WHERE ROUND(o.carrier_transit_days::numeric, 10)
                      IS DISTINCT FROM ROUND((
                          EXTRACT(EPOCH FROM (
                              f.order_delivered_customer_date
                              - f.order_delivered_carrier_date
                          )) / 86400.0
                      )::numeric, 10)
            ),
            COUNT(*) FILTER (
                WHERE o.delivery_delay_days IS DISTINCT FROM (
                    f.order_delivered_customer_date::date
                    - f.order_estimated_delivery_date::date
                )
            )
        FROM metrics.kpi_orders o
        JOIN analytics.fact_orders f USING (order_id)
        WHERE o.order_id IN (
            '000c3e6612759851cc3cbb4b83257986',
            '00685d31ae12e47470ba5c18ba74f22c',
            '00137e170939bba5a3134e2386413108',
            '000e906b789b55f64edcb1f84030f90d',
            '00061f2a7bc09da83e415a52dc8a4af1',
            '0032d07457ae9c806c79368d7d9ce96b',
            '00024acbcdf0a6daa1e931b038114c75',
            '003a94f778ef8cfd50247c8c1b582257'
        )
        """,
    )
    assert (n_rows, handling_bad, transit_bad, delay_bad) == (8, 0, 0, 0)

def test_seller_gmv_reconciles_to_item_price(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        WITH item_totals AS (
            SELECT
                seller_id,
                order_id,
                SUM(price) AS item_gmv
            FROM analytics.fact_order_items
            GROUP BY seller_id, order_id
        )
        SELECT COUNT(*)
        FROM metrics.kpi_seller_orders s
        FULL JOIN item_totals i
          ON i.seller_id = s.seller_id
         AND i.order_id = s.order_id
        WHERE s.order_id IS NULL
           OR i.order_id IS NULL
           OR s.seller_gmv IS DISTINCT FROM i.item_gmv
        """,
    )

    assert mismatches == 0

def test_product_category_gmv_reconciles_to_certified_marketplace(cursor):
    gmv_mismatches, late_gmv_mismatches = fetch_one(
        cursor,
        """
        WITH category AS (
            SELECT
                ROUND(SUM(gmv), 2) AS gmv,
                ROUND(SUM(late_gmv), 2) AS late_gmv
            FROM analysis.segment_fulfillment_performance
            WHERE segment_type = 'product_category'
        ),
        marketplace AS (
            SELECT
                ROUND(SUM(gmv), 2) AS gmv,
                ROUND(SUM(late_gmv), 2) AS late_gmv
            FROM metrics.kpi_orders
            WHERE is_comparable_trend_window
        )
        SELECT
            (c.gmv IS DISTINCT FROM m.gmv)::integer,
            (c.late_gmv IS DISTINCT FROM m.late_gmv)::integer
        FROM category c
        CROSS JOIN marketplace m
        """,
    )

    assert gmv_mismatches == 0
    assert late_gmv_mismatches == 0

def test_product_category_monthly_gmv_reconciles_to_certified_marketplace(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        WITH category AS (
            SELECT
                purchase_month,
                ROUND(SUM(gmv), 2) AS gmv,
                ROUND(SUM(late_gmv), 2) AS late_gmv
            FROM analysis.segment_fulfillment_month
            WHERE segment_type = 'product_category'
            GROUP BY purchase_month
        ),
        marketplace AS (
            SELECT
                purchase_month,
                ROUND(SUM(gmv), 2) AS gmv,
                ROUND(SUM(late_gmv), 2) AS late_gmv
            FROM metrics.kpi_orders
            WHERE is_comparable_trend_window
            GROUP BY purchase_month
        )
        SELECT COUNT(*)
        FROM category c
        FULL JOIN marketplace m USING (purchase_month)
        WHERE c.purchase_month IS NULL
           OR m.purchase_month IS NULL
           OR c.gmv IS DISTINCT FROM m.gmv
           OR c.late_gmv IS DISTINCT FROM m.late_gmv
        """,
    )

    assert mismatches == 0
