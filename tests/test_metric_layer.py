"""Structural and reconciliation checks for the metric layer."""

from decimal import Decimal

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


def test_order_metrics(cursor):
    row = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT order_id),
            COUNT(*) FILTER (WHERE is_delivered),
            COUNT(*) FILTER (WHERE is_delivery_performance_eligible),
            COUNT(*) FILTER (WHERE is_on_time),
            COUNT(*) FILTER (WHERE is_late),
            COUNT(*) FILTER (
                WHERE NOT is_delivery_performance_eligible
                  AND (is_on_time IS NOT NULL OR is_late IS NOT NULL)
            )
        FROM metrics.kpi_orders
        """,
    )

    rows, keys, delivered, eligible, on_time, late, bad_flags = row

    assert rows == keys == 99441
    assert delivered == 96478
    assert eligible == 96470
    assert (on_time, late) == (89936, 6534)
    assert on_time + late == eligible
    assert bad_flags == 0


def test_marketplace_metrics(cursor):
    row = fetch_one(
        cursor,
        """
        SELECT
            all_orders,
            delivery_performance_eligible,
            on_time_count,
            late_count,
            on_time_delivery_rate,
            late_delivery_rate,
            excluded_missing_actual_delivery,
            gmv,
            late_gmv,
            reviewed_orders,
            no_review_orders,
            review_unusable_only_orders
        FROM metrics.kpi_marketplace
        """,
    )

    (
        orders,
        eligible,
        on_time,
        late,
        on_time_rate,
        late_rate,
        missing_actual,
        gmv,
        late_gmv,
        reviewed,
        no_review,
        unusable,
    ) = row

    assert (orders, eligible, on_time, late) == (99441, 96470, 89936, 6534)
    assert abs(float(on_time_rate) + float(late_rate) - 1) < 1e-12
    assert missing_actual == 8
    assert gmv == Decimal("13591643.70")
    assert late_gmv == Decimal("985924.34")
    assert reviewed + no_review + unusable == orders


def test_duration_rules(cursor):
    negatives, invalid_handling = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE purchase_to_delivery_days < 0
                   OR seller_handling_days < 0
                   OR carrier_transit_days < 0
            ),
            COUNT(*) FILTER (
                WHERE NOT is_seller_handling_eligible
                  AND seller_handling_days IS NOT NULL
            )
        FROM metrics.kpi_orders
        """,
    )

    assert negatives == 0
    assert invalid_handling == 0


def test_seller_metrics(cursor):
    row = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM metrics.kpi_seller_orders),
            (
                SELECT COUNT(DISTINCT (seller_id, order_id))
                FROM metrics.kpi_seller_orders
            ),
            (
                SELECT COUNT(*)
                FROM (
                    SELECT seller_id, order_id
                    FROM analytics.fact_order_items
                    GROUP BY seller_id, order_id
                ) x
            ),
            (SELECT COUNT(*) FROM metrics.kpi_sellers),
            ROUND((SELECT SUM(price)
                   FROM analytics.fact_order_items), 2),
            ROUND((SELECT SUM(seller_gmv)
                   FROM metrics.kpi_seller_orders), 2),
            ROUND((SELECT SUM(gmv)
                   FROM metrics.kpi_orders), 2),
            (SELECT SUM(late_seller_orders)
             FROM metrics.kpi_sellers),
            (SELECT ROUND(SUM(seller_late_contribution), 10)
             FROM metrics.kpi_sellers)
        """,
    )

    (
        seller_rows,
        seller_keys,
        source_pairs,
        sellers,
        item_gmv,
        seller_gmv,
        order_gmv,
        late_units,
        contribution,
    ) = row

    assert seller_rows == seller_keys == source_pairs
    assert sellers == 3095
    assert item_gmv == seller_gmv == order_gmv == Decimal("13591643.70")
    assert late_units == 6547
    assert contribution == Decimal("1.0000000000")


def test_customer_metrics(cursor):
    buyers, first_orders, repeat_orders, bad_customers = fetch_one(
        cursor,
        """
        SELECT
            (SELECT COUNT(*) FROM metrics.kpi_customers),
            (
                SELECT COUNT(*)
                FROM metrics.kpi_orders
                WHERE customer_order_sequence = 1
            ),
            (
                SELECT COUNT(*)
                FROM metrics.kpi_orders
                WHERE is_repeat_order
            ),
            COUNT(*) FILTER (
                WHERE n_orders < 1
                   OR (is_repeat_customer AND n_orders < 2)
                   OR (NOT is_repeat_customer AND n_orders <> 1)
            )
        FROM metrics.kpi_customers
        """,
    )

    assert buyers == first_orders == 96096
    assert repeat_orders == 3345
    assert bad_customers == 0


def test_review_metrics(cursor):
    negative, reviewed, bad_unreviewed = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (WHERE is_negative_review),
            COUNT(*) FILTER (WHERE has_usable_review),
            COUNT(*) FILTER (
                WHERE NOT has_usable_review
                  AND is_negative_review IS NOT NULL
            )
        FROM metrics.kpi_orders
        """,
    )

    assert negative == 14197
    assert reviewed == 97530
    assert bad_unreviewed == 0


def test_reconciliation(cursor):
    source_late, metric_late, source_gmv, metric_gmv, monthly_orders, monthly_late = (
        fetch_one(
            cursor,
            """
            SELECT
                (
                    SELECT COUNT(*)
                    FROM analytics.fact_orders
                    WHERE order_status = 'delivered'
                      AND order_delivered_customer_date IS NOT NULL
                      AND order_estimated_delivery_date IS NOT NULL
                      AND order_delivered_customer_date::date
                          > order_estimated_delivery_date::date
                ),
                (SELECT late_count FROM metrics.kpi_marketplace),
                (
                    SELECT ROUND(SUM(price), 2)
                    FROM analytics.fact_order_items
                ),
                (SELECT gmv FROM metrics.kpi_marketplace),
                (
                    SELECT SUM(all_orders)
                    FROM metrics.kpi_marketplace_month
                ),
                (
                    SELECT SUM(late_count)
                    FROM metrics.kpi_marketplace_month
                )
            """,
        )
    )

    assert source_late == metric_late == monthly_late == 6534
    assert source_gmv == metric_gmv == Decimal("13591643.70")
    assert monthly_orders == 99441