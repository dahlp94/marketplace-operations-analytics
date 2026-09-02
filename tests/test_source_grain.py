"""Tests for important raw-source grain assumptions."""

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


def test_orders_have_unique_order_ids(cursor):
    rows, distinct_ids, null_ids = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT order_id),
            COUNT(*) FILTER (WHERE order_id IS NULL)
        FROM raw.orders
        """,
    )

    assert rows == distinct_ids
    assert null_ids == 0


def test_order_items_have_unique_composite_key(cursor):
    rows, distinct_keys = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT (order_id, order_item_id))
        FROM raw.order_items
        """,
    )

    assert rows == distinct_keys


def test_order_payments_have_unique_composite_key(cursor):
    rows, distinct_keys = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT (order_id, payment_sequential))
        FROM raw.order_payments
        """,
    )

    assert rows == distinct_keys


def test_customers_have_unique_customer_ids(cursor):
    rows, distinct_ids = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT customer_id)
        FROM raw.customers
        """,
    )

    assert rows == distinct_ids


def test_sellers_have_unique_seller_ids(cursor):
    rows, distinct_ids = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT seller_id)
        FROM raw.sellers
        """,
    )

    assert rows == distinct_ids


def test_products_have_unique_product_ids(cursor):
    rows, distinct_ids = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT product_id)
        FROM raw.products
        """,
    )

    assert rows == distinct_ids


def test_customer_unique_id_can_repeat(cursor):
    rows, distinct_buyers = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT customer_unique_id)
        FROM raw.customers
        """,
    )

    assert distinct_buyers < rows


def test_review_id_is_not_unique(cursor):
    rows, distinct_reviews = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT review_id)
        FROM raw.order_reviews
        """,
    )

    assert distinct_reviews < rows


def test_geolocation_zip_prefix_is_not_unique(cursor):
    rows, distinct_zip_codes = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT geolocation_zip_code_prefix)
        FROM raw.geolocation
        """,
    )

    assert distinct_zip_codes < rows


def test_orders_can_have_multiple_items_and_payments(cursor):
    item_rows, item_orders = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT order_id)
        FROM raw.order_items
        """,
    )

    payment_rows, payment_orders = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT order_id)
        FROM raw.order_payments
        """,
    )

    assert item_rows > item_orders
    assert payment_rows > payment_orders


def test_naive_item_payment_join_creates_fanout(cursor):
    item_rows, payment_rows, joined_rows = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM raw.order_items),
            (SELECT COUNT(*) FROM raw.order_payments),
            (
                SELECT COUNT(*)
                FROM raw.order_items i
                JOIN raw.order_payments p
                    ON i.order_id = p.order_id
            )
        """,
    )

    assert joined_rows > item_rows
    assert joined_rows > payment_rows