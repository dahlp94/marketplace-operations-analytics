"""Tests for important data-quality findings and treatment rules."""

from pathlib import Path

import pytest

from python.scripts.config import ROOT, connect


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn:
        with conn.cursor() as cursor:
            yield cursor


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def test_data_quality_report_exists():
    assert (ROOT / "docs" / "data_quality_report.md").exists()


def test_quality_investigation_outputs_exist():
    output_dir = ROOT / "outputs" / "quality_investigation"

    expected = [
        "08_review_anomalies.txt",
        "09_missingness.txt",
        "10_timestamp_validity.txt",
        "11_status_consistency.txt",
        "12_product_category.txt",
        "13_geography.txt",
        "14_monetary_reconciliation.txt",
        "15_time_coverage.txt",
        "16_treatment_impact.txt",
        "quality_investigation.txt",
    ]

    for name in expected:
        assert (output_dir / name).exists()


def test_reused_review_ids_match_investigation(cursor):
    reused_ids, review_rows = fetch_one(
        cursor,
        """
        WITH reused AS (
            SELECT review_id, COUNT(*) AS n_rows
            FROM raw.order_reviews
            GROUP BY review_id
            HAVING COUNT(*) > 1
        )
        SELECT
            COUNT(*),
            SUM(n_rows)
        FROM reused
        """,
    )

    assert reused_ids == 789
    assert review_rows == 1603


def test_delivered_missing_customer_timestamp_count(cursor):
    n, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM raw.orders
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
        """,
    )

    assert n == 8


def test_customer_before_carrier_delivered_count(cursor):
    n, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM raw.orders
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date < order_delivered_carrier_date
        """,
    )

    assert n == 23


def test_seller_handling_eligibility(cursor):
    n, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM raw.orders
        WHERE order_status = 'delivered'
          AND order_approved_at IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_approved_at >= order_purchase_timestamp
          AND order_delivered_carrier_date >= order_approved_at
        """,
    )

    assert n == 95112


def test_unpaid_delivered_order_is_known_case(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT o.order_id, o.order_status
        FROM raw.orders o
        LEFT JOIN raw.order_payments p
            ON p.order_id = o.order_id
        WHERE p.order_id IS NULL
        """,
    )

    assert rows == ("bfbd0f9bdef84302105ad712db648a6c", "delivered")


def test_product_category_gaps_match_investigation(cursor):
    missing, untranslated_products, untranslated_categories = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE p.product_category_name IS NULL
            ),
            COUNT(*) FILTER (
                WHERE p.product_category_name IS NOT NULL
                  AND t.product_category_name IS NULL
            ),
            COUNT(DISTINCT p.product_category_name) FILTER (
                WHERE p.product_category_name IS NOT NULL
                  AND t.product_category_name IS NULL
            )
        FROM raw.products p
        LEFT JOIN raw.product_category_translation t
            ON t.product_category_name = p.product_category_name
        """,
    )

    assert missing == 610
    assert untranslated_products == 13
    assert untranslated_categories == 2


def test_payment_item_freight_exact_match_is_typical(cursor):
    exact, total = fetch_one(
        cursor,
        """
        WITH item_totals AS (
            SELECT order_id, SUM(price + freight_value) AS item_total
            FROM raw.order_items
            GROUP BY order_id
        ),
        payment_totals AS (
            SELECT order_id, SUM(payment_value) AS pay_total
            FROM raw.order_payments
            GROUP BY order_id
        )
        SELECT
            COUNT(*) FILTER (WHERE p.pay_total = i.item_total),
            COUNT(*)
        FROM item_totals i
        JOIN payment_totals p
            ON p.order_id = i.order_id
        """,
    )

    assert total == 98665
    assert exact == 98089


def test_geolocation_zip_join_is_unsafe(cursor):
    customers, joined = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM raw.customers),
            (
                SELECT COUNT(*)
                FROM raw.customers c
                JOIN raw.geolocation g
                    ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
            )
        """,
    )

    assert joined > customers


def test_full_month_trend_window_count(cursor):
    n, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM raw.orders
        WHERE order_purchase_timestamp >= TIMESTAMP '2017-02-01'
          AND order_purchase_timestamp < TIMESTAMP '2018-09-01'
        """,
    )

    assert n == 98292
