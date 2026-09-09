"""Structural checks for metric definitions."""

from decimal import Decimal

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


def test_delivery_population_and_classes(cursor):
    early, on_time, late, eligible = fetch_one(
        cursor,
        f"""
        SELECT
            COUNT(*) FILTER (
                WHERE order_delivered_customer_date::date
                    < order_estimated_delivery_date::date
            ),
            COUNT(*) FILTER (
                WHERE order_delivered_customer_date::date
                    = order_estimated_delivery_date::date
            ),
            COUNT(*) FILTER (
                WHERE order_delivered_customer_date::date
                    > order_estimated_delivery_date::date
            ),
            COUNT(*)
        FROM analytics.fact_orders
        WHERE {DELIVERY_ELIGIBLE}
        """,
    )

    assert (early, on_time, late, eligible) == (88644, 1292, 6534, 96470)
    assert early + on_time + late == eligible


def test_duration_eligibility(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (WHERE eligible_purchase_to_delivery),
            COUNT(*) FILTER (WHERE eligible_seller_handling),
            COUNT(*) FILTER (WHERE eligible_carrier_transit)
        FROM analytics.fact_orders
        """,
    )

    assert result == (96470, 95112, 96281)


def test_eligible_durations_are_non_negative(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE eligible_purchase_to_delivery
                  AND order_delivered_customer_date < order_purchase_timestamp
            ),
            COUNT(*) FILTER (
                WHERE eligible_seller_handling
                  AND order_delivered_carrier_date < order_approved_at
            ),
            COUNT(*) FILTER (
                WHERE eligible_carrier_transit
                  AND order_delivered_customer_date < order_delivered_carrier_date
            )
        FROM analytics.fact_orders
        """,
    )

    assert result == (0, 0, 0)


def test_seller_gmv_reconciles(cursor):
    seller_gmv, order_gmv, late_seller_gmv, late_order_gmv = fetch_one(
        cursor,
        f"""
        WITH eligible AS (
            SELECT
                order_id,
                merchandise_value,
                order_delivered_customer_date::date
                    > order_estimated_delivery_date::date AS is_late
            FROM analytics.fact_orders
            WHERE {DELIVERY_ELIGIBLE}
        )
        SELECT
            (
                SELECT ROUND(SUM(i.price), 2)
                FROM analytics.fact_order_items i
                JOIN eligible e USING (order_id)
            ),
            (
                SELECT ROUND(SUM(merchandise_value), 2)
                FROM eligible
            ),
            (
                SELECT ROUND(SUM(i.price), 2)
                FROM analytics.fact_order_items i
                JOIN eligible e USING (order_id)
                WHERE e.is_late
            ),
            (
                SELECT ROUND(SUM(merchandise_value), 2)
                FROM eligible
                WHERE is_late
            )
        """,
    )

    assert seller_gmv == order_gmv == Decimal("13220248.93")
    assert late_seller_gmv == late_order_gmv == Decimal("985924.34")


def test_multi_seller_late_order_gap(cursor):
    late_orders, late_seller_orders, extra_units = fetch_one(
        cursor,
        f"""
        WITH eligible AS (
            SELECT
                order_id,
                n_sellers,
                order_delivered_customer_date::date
                    > order_estimated_delivery_date::date AS is_late
            FROM analytics.fact_orders
            WHERE {DELIVERY_ELIGIBLE}
        ),
        seller_orders AS (
            SELECT DISTINCT seller_id, order_id
            FROM analytics.fact_order_items
        )
        SELECT
            COUNT(*) FILTER (WHERE is_late),
            (
                SELECT COUNT(*)
                FROM seller_orders s
                JOIN eligible e USING (order_id)
                WHERE e.is_late
            ),
            SUM(n_sellers - 1) FILTER (
                WHERE is_late AND n_sellers > 1
            )
        FROM eligible
        """,
    )

    assert (late_orders, late_seller_orders, extra_units) == (6534, 6547, 13)
    assert late_seller_orders == late_orders + extra_units


def test_review_populations(cursor):
    reviewed, unusable, no_review, total = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (WHERE n_usable_review_rows > 0),
            COUNT(*) FILTER (
                WHERE n_review_rows > 0
                  AND n_usable_review_rows = 0
            ),
            COUNT(*) FILTER (WHERE n_review_rows = 0),
            COUNT(*)
        FROM analytics.fact_orders
        """,
    )

    assert (reviewed, unusable, no_review) == (97530, 1143, 768)
    assert reviewed + unusable + no_review == total


def test_repeat_customer_sequence(cursor):
    buyers, first_orders, repeat_orders, total_orders = fetch_one(
        cursor,
        """
        WITH sequenced AS (
            SELECT
                o.order_id,
                c.customer_unique_id,
                ROW_NUMBER() OVER (
                    PARTITION BY c.customer_unique_id
                    ORDER BY o.order_purchase_timestamp, o.order_id
                ) AS order_sequence
            FROM analytics.fact_orders o
            JOIN analytics.dim_customer c USING (customer_id)
        )
        SELECT
            COUNT(DISTINCT customer_unique_id),
            COUNT(*) FILTER (WHERE order_sequence = 1),
            COUNT(*) FILTER (WHERE order_sequence > 1),
            COUNT(*)
        FROM sequenced
        """,
    )

    assert buyers == first_orders == 96096
    assert repeat_orders == 3345
    assert total_orders == 99441
    assert first_orders + repeat_orders == total_orders