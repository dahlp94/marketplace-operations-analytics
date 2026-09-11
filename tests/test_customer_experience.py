"""Validate customer-experience outputs against certified review metrics."""

import pytest

from python.scripts.config import connect

@pytest.fixture(scope="module")
def cursor():
    with connect() as conn, conn.cursor() as cur:
        yield cur

def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()

def test_review_coverage_matches_certified_counts(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            a.orders,
            a.reviewed_orders,
            a.negative_review_orders,
            d.orders,
            d.reviewed_orders
        FROM analysis.review_coverage a
        JOIN analysis.review_coverage d
          ON d.population = 'delivered_orders'
        WHERE a.population = 'all_orders'
        """,
    )
    assert result == (99441, 97530, 14197, 96478, 94782)

def test_unreviewed_orders_are_not_negative(cursor):
    bad, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM metrics.kpi_orders
        WHERE NOT has_usable_review
          AND is_negative_review IS NOT NULL
        """,
    )
    assert bad == 0

def test_review_score_distribution_matches_source(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        WITH source AS (
            SELECT
                delivery_class,
                COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed
            FROM metrics.kpi_orders
            WHERE is_delivery_performance_eligible
            GROUP BY delivery_class
        ),
        extract AS (
            SELECT
                delivery_class,
                SUM(reviewed_orders)::integer AS reviewed
            FROM analysis.review_score_distribution
            GROUP BY delivery_class
        )
        SELECT COUNT(*)
        FROM source s
        FULL JOIN extract e USING (delivery_class)
        WHERE s.reviewed IS DISTINCT FROM e.reviewed
        """,
    )
    assert mismatches == 0

def test_delay_bands_partition_eligible_orders(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            SUM(eligible_orders),
            SUM(reviewed_orders),
            COUNT(*) FILTER (
                WHERE delay_band <> 'late_31plus'
                  AND is_low_sample
            )
        FROM analysis.delay_band_reviews
        """,
    )
    assert result == (96470, 94774, 0)

def test_review_selection_partitions_delivered_orders(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            SUM(delivered_orders),
            SUM(eligible_orders)
        FROM analysis.review_selection
        """,
    )
    assert result == (96478, 96470)

def test_category_gmv_and_sparse_segments_are_valid(cursor):
    segment_gmv, kpi_gmv, has_low_sample, unflagged_tiny = fetch_one(
        cursor,
        """
        SELECT
            (
                SELECT ROUND(SUM(gmv), 2)
                FROM analysis.segment_review_performance
                WHERE segment_type = 'product_category'
            ),
            (
                SELECT ROUND(SUM(gmv), 2)
                FROM metrics.kpi_orders
                WHERE is_delivery_performance_eligible
            ),
            EXISTS (
                SELECT 1
                FROM analysis.segment_review_performance
                WHERE is_low_sample
            ),
            (
                SELECT COUNT(*)
                FROM analysis.segment_review_performance
                WHERE reviewed_orders < 100
                  AND NOT is_low_sample
            )
        """,
    )
    assert segment_gmv == kpi_gmv
    assert has_low_sample
    assert unflagged_tiny == 0


def test_spot_checks_match_fact_orders(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM metrics.kpi_orders o
        JOIN analytics.fact_orders f USING (order_id)
        WHERE o.order_id IN (
            '0017afd5076e074a48f1f1a4c7bac9c5',
            '00010242fe8c5a6d1ba2dd792cb16214',
            '00143d0f86d6fbd9f9b38ab440ac16f5',
            '0005a1a1728c9d785b8e2b08b904576c'
        )
          AND (
              o.delivery_delay_days IS DISTINCT FROM (
                  f.order_delivered_customer_date::date
                  - f.order_estimated_delivery_date::date
              )
              OR o.order_review_score IS DISTINCT FROM f.order_review_score
              OR (NOT o.has_usable_review AND o.is_negative_review IS NOT NULL)
          )
        """,
    )
    assert mismatches == 0
