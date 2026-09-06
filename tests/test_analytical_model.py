"""Tests for analytical-model grain, treatments, and join safety."""

import pytest

from python.scripts.config import connect


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn:
        with conn.cursor() as cursor:
            yield cursor


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def test_fact_and_dimension_counts_match_raw(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM analytics.fact_orders),
            (SELECT COUNT(*) FROM analytics.fact_order_items),
            (SELECT COUNT(*) FROM analytics.fact_payments),
            (SELECT COUNT(*) FROM analytics.fact_reviews),
            (SELECT COUNT(*) FROM analytics.dim_customer),
            (SELECT COUNT(*) FROM analytics.dim_seller),
            (SELECT COUNT(*) FROM analytics.dim_product)
        """,
    )

    assert rows == (
        99441,
        112650,
        103886,
        99224,
        99441,
        3095,
        32951,
    )


def test_dimension_and_fact_keys_are_unique(cursor):
    checks = [
        "SELECT COUNT(*), COUNT(DISTINCT date_day) FROM analytics.dim_date",
        """
        SELECT COUNT(*), COUNT(DISTINCT zip_code_prefix)
        FROM analytics.dim_geography
        """,
        """
        SELECT COUNT(*), COUNT(DISTINCT customer_id)
        FROM analytics.dim_customer
        """,
        """
        SELECT COUNT(*), COUNT(DISTINCT seller_id)
        FROM analytics.dim_seller
        """,
        """
        SELECT COUNT(*), COUNT(DISTINCT product_id)
        FROM analytics.dim_product
        """,
        """
        SELECT COUNT(*), COUNT(DISTINCT order_id)
        FROM analytics.fact_orders
        """,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT (order_id, order_item_id))
        FROM analytics.fact_order_items
        """,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT (order_id, payment_sequential))
        FROM analytics.fact_payments
        """,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT (review_id, order_id))
        FROM analytics.fact_reviews
        """,
    ]

    for sql in checks:
        n_rows, n_keys = fetch_one(cursor, sql)
        assert n_rows == n_keys


def test_customer_identity_is_preserved(cursor):
    rows, unique_buyers = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT customer_unique_id)
        FROM analytics.dim_customer
        """,
    )

    assert rows == 99441
    assert unique_buyers == 96096
    assert unique_buyers < rows


def test_geography_join_is_safe(cursor):
    (
        customers,
        customer_joined,
        customer_unmatched,
        sellers,
        seller_joined,
        seller_unmatched,
    ) = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM analytics.dim_customer),

            (
                SELECT COUNT(*)
                FROM analytics.dim_customer c
                JOIN analytics.dim_geography g
                    ON g.zip_code_prefix = c.zip_code_prefix
            ),

            (
                SELECT COUNT(*)
                FROM analytics.dim_customer c
                JOIN analytics.dim_geography g
                    ON g.zip_code_prefix = c.zip_code_prefix
                WHERE g.geo_unmatched
            ),

            (SELECT COUNT(*) FROM analytics.dim_seller),

            (
                SELECT COUNT(*)
                FROM analytics.dim_seller s
                JOIN analytics.dim_geography g
                    ON g.zip_code_prefix = s.zip_code_prefix
            ),

            (
                SELECT COUNT(*)
                FROM analytics.dim_seller s
                JOIN analytics.dim_geography g
                    ON g.zip_code_prefix = s.zip_code_prefix
                WHERE g.geo_unmatched
            )
        """,
    )

    assert customer_joined == customers == 99441
    assert seller_joined == sellers == 3095
    assert customer_unmatched == 278
    assert seller_unmatched == 7


def test_child_facts_do_not_fan_out_against_orders(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM analytics.fact_order_items),

            (
                SELECT COUNT(*)
                FROM analytics.fact_order_items i
                JOIN analytics.fact_orders o
                    ON o.order_id = i.order_id
            ),

            (SELECT COUNT(*) FROM analytics.fact_payments),

            (
                SELECT COUNT(*)
                FROM analytics.fact_payments p
                JOIN analytics.fact_orders o
                    ON o.order_id = p.order_id
            ),

            (SELECT COUNT(*) FROM analytics.fact_reviews),

            (
                SELECT COUNT(*)
                FROM analytics.fact_reviews r
                JOIN analytics.fact_orders o
                    ON o.order_id = r.order_id
            )
        """,
    )

    items, items_joined, payments, payments_joined, reviews, reviews_joined = rows

    assert items_joined == items == 112650
    assert payments_joined == payments == 103886
    assert reviews_joined == reviews == 99224


def test_order_rollups_match_child_facts(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            (
                SELECT ROUND(SUM(price), 2)
                FROM analytics.fact_order_items
            ),

            (
                SELECT ROUND(SUM(merchandise_value), 2)
                FROM analytics.fact_orders
            ),

            (
                SELECT ROUND(SUM(item_side_value), 2)
                FROM analytics.fact_order_items
            ),

            (
                SELECT ROUND(SUM(item_side_value), 2)
                FROM analytics.fact_orders
            ),

            (
                SELECT ROUND(SUM(payment_value), 2)
                FROM analytics.fact_payments
            ),

            (
                SELECT ROUND(SUM(collected_payment), 2)
                FROM analytics.fact_orders
            )
        """,
    )

    (
        merchandise_native,
        merchandise_rollup,
        item_side_native,
        item_side_rollup,
        payment_native,
        payment_rollup,
    ) = rows

    assert merchandise_native == merchandise_rollup
    assert item_side_native == item_side_rollup
    assert payment_native == payment_rollup


def test_metric_eligibility_matches_quality_investigation(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE order_status = 'delivered'
            ),

            COUNT(*) FILTER (
                WHERE eligible_on_time_delivery
            ),

            COUNT(*) FILTER (
                WHERE eligible_purchase_to_delivery
            ),

            COUNT(*) FILTER (
                WHERE eligible_seller_handling
            ),

            COUNT(*) FILTER (
                WHERE eligible_carrier_transit
            )
        FROM analytics.fact_orders
        """,
    )

    assert rows == (
        96478,
        96470,
        96470,
        95112,
        96281,
    )


def test_product_category_treatment(cursor):
    unknown, fallback = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE category_assignment = 'unknown'
            ),

            COUNT(*) FILTER (
                WHERE category_assignment = 'portuguese_fallback'
            )
        FROM analytics.dim_product
        """,
    )

    assert unknown == 610
    assert fallback == 13


def test_review_reuse_treatment(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),

            COUNT(*) FILTER (
                WHERE review_id_reused
            ),

            COUNT(*) FILTER (
                WHERE NOT review_id_reused
            ),

            COUNT(DISTINCT order_id) FILTER (
                WHERE review_id_reused
            )
        FROM analytics.fact_reviews
        """,
    )

    assert rows == (
        99224,
        1603,
        97621,
        1412,
    )


def test_monetary_difference_flag(cursor):
    n, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analytics.fact_orders
        WHERE monetary_diff_gt_tolerance
        """,
    )

    assert n == 303


def test_known_unpaid_delivered_order_is_retained(cursor):
    status, n_payment_rows, collected_payment = fetch_one(
        cursor,
        """
        SELECT
            order_status,
            n_payment_rows,
            collected_payment
        FROM analytics.fact_orders
        WHERE order_id = 'bfbd0f9bdef84302105ad712db648a6c'
        """,
    )

    assert status == "delivered"
    assert n_payment_rows == 0
    assert collected_payment is None


def test_full_month_trend_window_count(cursor):
    n, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analytics.fact_orders
        WHERE purchase_date >= DATE '2017-02-01'
          AND purchase_date < DATE '2018-09-01'
        """,
    )

    assert n == 98292


def test_source_statuses_are_preserved(cursor):
    statuses = fetch_one(
        cursor,
        """
        SELECT ARRAY_AGG(
            DISTINCT order_status
            ORDER BY order_status
        )
        FROM analytics.fact_orders
        """,
    )[0]

    assert set(statuses) == {
        "approved",
        "canceled",
        "created",
        "delivered",
        "invoiced",
        "processing",
        "shipped",
        "unavailable",
    }


def test_required_order_fields_are_not_null(cursor):
    n, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analytics.fact_orders
        WHERE order_id IS NULL
           OR customer_id IS NULL
           OR order_status IS NULL
           OR order_purchase_timestamp IS NULL
           OR purchase_date IS NULL
        """,
    )

    assert n == 0