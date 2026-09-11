"""Validate statistical populations, intervals, and model outputs."""

import numpy as np
import pandas as pd
import pytest
import statsmodels.stats.proportion as smprop

from python.scripts.config import ANALYSIS_OUTPUT_DIR, connect
from python.scripts.statistical_validation import diff_ci, wilson_ci


@pytest.fixture(scope="module")
def cursor():
    with connect() as conn, conn.cursor() as cur:
        yield cur


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def test_inference_population_matches_certified_orders(cursor):
    result = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*),
            COUNT(DISTINCT order_id),
            COUNT(*) FILTER (WHERE is_delivery_performance_eligible),
            (SELECT COUNT(*) FILTER (WHERE is_delivered) FROM metrics.kpi_orders),
            (SELECT COUNT(*) FILTER (WHERE is_delivery_performance_eligible)
             FROM metrics.kpi_orders)
        FROM analysis.inference_orders
        """,
    )
    assert result[0] == result[1] == result[3]
    assert result[2] == result[4] == 96470


def test_unreviewed_orders_are_not_negative(cursor):
    bad, = fetch_one(
        cursor,
        """
        SELECT COUNT(*)
        FROM analysis.inference_orders
        WHERE NOT has_usable_review
          AND is_negative_review IS NOT NULL
        """,
    )
    assert bad == 0


def test_inference_rates_reuse_certified_sources(cursor):
    mismatches, = fetch_one(
        cursor,
        """
        WITH source AS (
            SELECT
                'marketplace_late_all_eligible'::text AS population,
                late_count::integer AS numerator,
                delivery_performance_eligible::integer AS denominator
            FROM metrics.kpi_marketplace

            UNION ALL

            SELECT
                'negative_review_' || delivery_class,
                negative_review_orders,
                reviewed_orders
            FROM analysis.delivery_class_review_rates
            WHERE delivery_class IN ('early', 'late')

            UNION ALL

            SELECT
                'watchlist_seller_order_late',
                SUM(late_seller_orders)::integer,
                SUM(delivery_eligible_seller_orders)::integer
            FROM analysis.seller_watchlist
        )
        SELECT COUNT(*)
        FROM source s
        JOIN analysis.inference_rate_counts i USING (population)
        WHERE i.numerator IS DISTINCT FROM s.numerator
           OR i.denominator IS DISTINCT FROM s.denominator
        """,
    )
    assert mismatches == 0


def test_model_population_matches_reviewed_eligible_orders(cursor):
    reviewed, unreviewed_late_higher = fetch_one(
        cursor,
        """
        SELECT
            COUNT(*) FILTER (
                WHERE is_delivery_performance_eligible
                  AND has_usable_review
            ),
            AVG(is_late::int) FILTER (
                WHERE is_delivery_performance_eligible
                  AND NOT has_usable_review
            ) > AVG(is_late::int) FILTER (
                WHERE is_delivery_performance_eligible
                  AND has_usable_review
            )
        FROM analysis.inference_orders
        """,
    )
    assert reviewed == 94774
    assert unreviewed_late_higher


def test_wilson_interval_matches_statsmodels():
    for successes, n in ((3932, 6307), (7945, 87203), (6509, 95453)):
        low, high = wilson_ci(successes, n)
        expected = smprop.proportion_confint(successes, n, method="wilson")
        assert np.allclose((low, high), expected)


def test_late_early_difference_excludes_zero():
    diff, low, high, pvalue = diff_ci(3932, 6307, 7945, 87203)

    assert 0.50 < diff < 0.56
    assert low > 0
    assert high > 0
    assert pvalue < 1e-10


def test_generated_model_and_sensitivity_outputs():
    model_path = ANALYSIS_OUTPUT_DIR / "review_outcome_model.csv"
    sensitivity_path = ANALYSIS_OUTPUT_DIR / "statistical_sensitivity.csv"

    if not model_path.exists() or not sensitivity_path.exists():
        pytest.skip("statistical validation outputs have not been generated")

    model = pd.read_csv(model_path).set_index("term")
    sensitivity = pd.read_csv(sensitivity_path).set_index("slice")

    assert model.loc["late_1_3", "odds_ratio"] > 1
    assert model.loc["late_1_3", "or_ci_low"] > 1

    for name in (
        "all_reviewed_eligible",
        "comparable_window",
        "exclude_late_31plus",
        "exclude_p99_delay",
    ):
        assert sensitivity.loc[name, "rate_difference"] > 0.45
