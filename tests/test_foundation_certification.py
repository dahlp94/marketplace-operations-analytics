"""Independent certification checks against raw source data."""

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


def test_order_ids_match_raw_exactly(cursor):
    missing, extra = fetch_one(
        cursor,
        """
        SELECT
            (
                SELECT COUNT(*)
                FROM raw.orders r
                LEFT JOIN analytics.fact_orders a
                    ON a.order_id = r.order_id
                WHERE a.order_id IS NULL
            ),
            (
                SELECT COUNT(*)
                FROM analytics.fact_orders a
                LEFT JOIN raw.orders r
                    ON r.order_id = a.order_id
                WHERE r.order_id IS NULL
            )
        """,
    )

    assert missing == 0
    assert extra == 0


def test_order_status_populations_match_raw(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM (
            SELECT
                COALESCE(r.order_status, a.order_status) AS order_status,
                COALESCE(r.n_orders, 0) AS raw_orders,
                COALESCE(a.n_orders, 0) AS analytical_orders
            FROM (
                SELECT order_status, COUNT(*) AS n_orders
                FROM raw.orders
                GROUP BY order_status
            ) r
            FULL OUTER JOIN (
                SELECT order_status, COUNT(*) AS n_orders
                FROM analytics.fact_orders
                GROUP BY order_status
            ) a
                ON a.order_status = r.order_status
        ) x
        WHERE raw_orders <> analytical_orders
        """,
    )

    assert mismatches == 0


def test_monetary_totals_reconcile(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            (SELECT ROUND(SUM(price), 2)
             FROM raw.order_items),

            (SELECT ROUND(SUM(price), 2)
             FROM analytics.fact_order_items),

            (SELECT ROUND(SUM(merchandise_value), 2)
             FROM analytics.fact_orders),

            (SELECT ROUND(SUM(freight_value), 2)
             FROM raw.order_items),

            (SELECT ROUND(SUM(freight_value), 2)
             FROM analytics.fact_order_items),

            (SELECT ROUND(SUM(freight_value), 2)
             FROM analytics.fact_orders),

            (SELECT ROUND(SUM(payment_value), 2)
             FROM raw.order_payments),

            (SELECT ROUND(SUM(payment_value), 2)
             FROM analytics.fact_payments),

            (SELECT ROUND(SUM(collected_payment), 2)
             FROM analytics.fact_orders)
        """,
    )

    (
        raw_price,
        item_price,
        order_price,
        raw_freight,
        item_freight,
        order_freight,
        raw_payment,
        fact_payment,
        order_payment,
    ) = rows

    assert raw_price == item_price == order_price
    assert raw_freight == item_freight == order_freight
    assert raw_payment == fact_payment == order_payment


def test_delivery_eligibility_recalculates_from_raw(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            (
                SELECT COUNT(*)
                FROM raw.orders
                WHERE order_status = 'delivered'
                  AND order_delivered_customer_date IS NOT NULL
            ),
            (
                SELECT COUNT(*)
                FROM analytics.fact_orders
                WHERE eligible_on_time_delivery
            ),

            (
                SELECT COUNT(*)
                FROM raw.orders
                WHERE order_status = 'delivered'
                  AND order_delivered_customer_date IS NOT NULL
                  AND order_delivered_customer_date >= order_purchase_timestamp
            ),
            (
                SELECT COUNT(*)
                FROM analytics.fact_orders
                WHERE eligible_purchase_to_delivery
            ),

            (
                SELECT COUNT(*)
                FROM raw.orders
                WHERE order_status = 'delivered'
                  AND order_approved_at IS NOT NULL
                  AND order_delivered_carrier_date IS NOT NULL
                  AND order_approved_at >= order_purchase_timestamp
                  AND order_delivered_carrier_date >= order_approved_at
            ),
            (
                SELECT COUNT(*)
                FROM analytics.fact_orders
                WHERE eligible_seller_handling
            ),

            (
                SELECT COUNT(*)
                FROM raw.orders
                WHERE order_status = 'delivered'
                  AND order_delivered_carrier_date IS NOT NULL
                  AND order_delivered_customer_date IS NOT NULL
                  AND order_delivered_carrier_date >= order_purchase_timestamp
                  AND order_delivered_customer_date >= order_delivered_carrier_date
            ),
            (
                SELECT COUNT(*)
                FROM analytics.fact_orders
                WHERE eligible_carrier_transit
            )
        """,
    )

    (
        raw_on_time,
        fact_on_time,
        raw_delivery,
        fact_delivery,
        raw_handling,
        fact_handling,
        raw_transit,
        fact_transit,
    ) = rows

    assert raw_on_time == fact_on_time == 96470
    assert raw_delivery == fact_delivery == 96470
    assert raw_handling == fact_handling == 95112
    assert raw_transit == fact_transit == 96281


def test_quality_treatments_recalculate_from_raw(cursor):
    rows = fetch_one(
        cursor,
        """
        SELECT
            (
                SELECT COUNT(*)
                FROM raw.order_reviews
                WHERE review_id IN (
                    SELECT review_id
                    FROM raw.order_reviews
                    GROUP BY review_id
                    HAVING COUNT(*) > 1
                )
            ),
            (
                SELECT COUNT(*)
                FROM analytics.fact_reviews
                WHERE review_id_reused
            ),

            (
                SELECT COUNT(*)
                FROM raw.products
                WHERE product_category_name IS NULL
            ),
            (
                SELECT COUNT(*)
                FROM analytics.dim_product
                WHERE category_assignment = 'unknown'
            ),

            (
                SELECT COUNT(*)
                FROM raw.products p
                LEFT JOIN raw.product_category_translation t
                    ON t.product_category_name = p.product_category_name
                WHERE p.product_category_name IS NOT NULL
                  AND t.product_category_name IS NULL
            ),
            (
                SELECT COUNT(*)
                FROM analytics.dim_product
                WHERE category_assignment = 'portuguese_fallback'
            )
        """,
    )

    (
        raw_reused_reviews,
        fact_reused_reviews,
        raw_unknown_categories,
        fact_unknown_categories,
        raw_fallback_categories,
        fact_fallback_categories,
    ) = rows

    assert raw_reused_reviews == fact_reused_reviews == 1603
    assert raw_unknown_categories == fact_unknown_categories == 610
    assert raw_fallback_categories == fact_fallback_categories == 13


def test_no_source_values_are_silently_rewritten(cursor):
    status_changes, item_changes, review_changes = fetch_one(
        cursor,
        """
        SELECT
            (
                SELECT COUNT(*)
                FROM raw.orders r
                JOIN analytics.fact_orders a
                    ON a.order_id = r.order_id
                WHERE r.order_status IS DISTINCT FROM a.order_status
            ),

            (
                SELECT COUNT(*)
                FROM raw.order_items r
                JOIN analytics.fact_order_items a
                    ON a.order_id = r.order_id
                   AND a.order_item_id = r.order_item_id
                WHERE r.price IS DISTINCT FROM a.price
                   OR r.freight_value IS DISTINCT FROM a.freight_value
            ),

            (
                SELECT COUNT(*)
                FROM raw.order_reviews r
                JOIN analytics.fact_reviews a
                    ON a.review_id = r.review_id
                   AND a.order_id = r.order_id
                WHERE r.review_score IS DISTINCT FROM a.review_score
            )
        """,
    )

    assert status_changes == 0
    assert item_changes == 0
    assert review_changes == 0