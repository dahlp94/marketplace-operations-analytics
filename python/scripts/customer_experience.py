"""Customer experience analysis: delivery performance and review outcomes."""

from __future__ import annotations

from decimal import Decimal
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from python.scripts.config import ANALYSIS_OUTPUT_DIR, FIGURES_OUTPUT_DIR, SQL_DIR


DELAY_LABELS = {
    "early_15plus": "15+ days early",
    "early_8_14": "8–14 days early",
    "early_4_7": "4–7 days early",
    "early_1_3": "1–3 days early",
    "on_time": "On time",
    "late_1_3": "1–3 days late",
    "late_4_7": "4–7 days late",
    "late_8_14": "8–14 days late",
    "late_15_30": "15–30 days late",
    "late_31plus": "31+ days late",
}


def read_sql(conn, sql: str) -> pd.DataFrame:
    with conn.cursor() as cur:
        cur.execute(sql)
        frame = pd.DataFrame(cur.fetchall(), columns=[c[0] for c in cur.description])

    for col in frame.select_dtypes("object"):
        if frame[col].map(lambda x: isinstance(x, Decimal)).any():
            frame[col] = pd.to_numeric(frame[col], errors="coerce")
    return frame


def rebuild_extracts(conn) -> None:
    sql = (SQL_DIR / "analysis" / "customer_experience.sql").read_text()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def load_extracts(conn) -> dict[str, pd.DataFrame]:
    queries = {
        "coverage": "SELECT * FROM analysis.review_coverage ORDER BY population",
        "delay_bands": """
            SELECT * FROM analysis.delay_band_reviews
            ORDER BY delay_band_sort
        """,
        "selection": """
            SELECT * FROM analysis.review_selection
            ORDER BY review_availability
        """,
        "month": """
            SELECT * FROM analysis.delivery_review_month
            ORDER BY purchase_month
        """,
        "segments": """
            SELECT * FROM analysis.segment_review_performance
            ORDER BY segment_type, negative_review_orders DESC NULLS LAST, segment_key
        """,
        "delivery_rates": """
            SELECT
                delivery_class,
                COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed_orders,
                COUNT(*) FILTER (WHERE is_negative_review)::integer AS negative_review_orders,
                COUNT(*) FILTER (WHERE is_negative_review)::numeric
                    / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
                    AS negative_review_rate,
                AVG(order_review_score) AS avg_review_score
            FROM metrics.kpi_orders
            WHERE is_delivery_performance_eligible
            GROUP BY delivery_class
            ORDER BY delivery_class
        """,
    }
    return {name: read_sql(conn, sql) for name, sql in queries.items()}


def export_extracts(frames: dict[str, pd.DataFrame]) -> list[Path]:
    ANALYSIS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    files = {
        "coverage": "review_coverage.csv",
        "delivery_rates": "delivery_class_review_rates.csv",
        "delay_bands": "delay_band_reviews.csv",
        "selection": "review_selection.csv",
        "month": "delivery_review_month.csv",
        "segments": "segment_review_performance.csv",
    }

    paths = []
    for name, filename in files.items():
        path = ANALYSIS_OUTPUT_DIR / filename
        frames[name].to_csv(path, index=False)
        paths.append(path)
    return paths


def delay_sensitivity(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        WITH p99 AS (
            SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (
                ORDER BY delivery_delay_days
            ) AS delay_p99
            FROM metrics.kpi_orders
            WHERE is_delivery_performance_eligible
        ),
        slices AS (
            SELECT 'all_eligible'::text AS slice, o.*
            FROM metrics.kpi_orders o
            WHERE is_delivery_performance_eligible

            UNION ALL

            SELECT 'exclude_p99_delay', o.*
            FROM metrics.kpi_orders o
            CROSS JOIN p99
            WHERE is_delivery_performance_eligible
              AND delivery_delay_days <= delay_p99

            UNION ALL

            SELECT 'exclude_late_31plus', o.*
            FROM metrics.kpi_orders o
            WHERE is_delivery_performance_eligible
              AND delivery_delay_days <= 30
        )
        SELECT
            slice,
            delivery_class,
            COUNT(*) FILTER (WHERE has_usable_review)::integer AS reviewed_orders,
            COUNT(*) FILTER (WHERE is_negative_review)::integer AS negative_review_orders,
            COUNT(*) FILTER (WHERE is_negative_review)::numeric
                / NULLIF(COUNT(*) FILTER (WHERE has_usable_review), 0)
                AS negative_review_rate
        FROM slices
        GROUP BY slice, delivery_class
        ORDER BY slice, delivery_class
        """,
    )


def order_spot_checks(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        SELECT
            o.order_id,
            o.delivery_class,
            o.delivery_delay_days AS kpi_delay_days,
            f.order_delivered_customer_date::date
                - f.order_estimated_delivery_date::date AS source_delay_days,
            o.order_review_score AS kpi_review_score,
            f.order_review_score AS source_review_score,
            o.is_negative_review
        FROM metrics.kpi_orders o
        JOIN analytics.fact_orders f USING (order_id)
        WHERE o.order_id IN (
            '0017afd5076e074a48f1f1a4c7bac9c5',
            '00010242fe8c5a6d1ba2dd792cb16214',
            '00143d0f86d6fbd9f9b38ab440ac16f5',
            '0005a1a1728c9d785b8e2b08b904576c'
        )
        ORDER BY o.order_id
        """,
    )


def write_validation_report(
    frames: dict[str, pd.DataFrame],
    sensitivity: pd.DataFrame,
    spot_checks: pd.DataFrame,
) -> Path:
    coverage = frames["coverage"].set_index("population")
    rates = frames["delivery_rates"].set_index("delivery_class")

    lines = [
        "Customer experience validation",
        "",
        f"Reviewed orders: {int(coverage.loc['all_orders', 'reviewed_orders']):,}",
        f"Delivered review coverage: {coverage.loc['delivered_orders', 'review_coverage']:.2%}",
        "",
        "Negative review rate by delivery class",
    ]

    for cls in ("early", "on_time", "late"):
        row = rates.loc[cls]
        lines.append(
            f"{cls}: {int(row['negative_review_orders'])} / "
            f"{int(row['reviewed_orders'])} = {row['negative_review_rate']:.2%}"
        )

    lines += ["", "Late-order sensitivity"]
    for row in sensitivity[sensitivity["delivery_class"] == "late"].itertuples():
        lines.append(
            f"{row.slice}: {int(row.negative_review_orders)} / "
            f"{int(row.reviewed_orders)} = {row.negative_review_rate:.2%}"
        )

    lines += ["", "Order spot checks"]
    for row in spot_checks.itertuples():
        lines.append(
            f"{row.order_id}: delay {row.kpi_delay_days}/{row.source_delay_days}, "
            f"score {row.kpi_review_score}/{row.source_review_score}"
        )

    path = ANALYSIS_OUTPUT_DIR / "customer_experience_validation.txt"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def make_figures(frames: dict[str, pd.DataFrame]) -> list[Path]:
    FIGURES_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    return [
        _delivery_class(frames["delivery_rates"]),
        _delay_bands(frames["delay_bands"]),
        _gmv_stratification(frames["segments"]),
        _review_selection(frames["selection"]),
    ]


def _save(fig, filename: str) -> Path:
    path = FIGURES_OUTPUT_DIR / filename
    fig.tight_layout()
    fig.savefig(path, dpi=140)
    plt.close(fig)
    return path


def _delivery_class(data: pd.DataFrame) -> Path:
    data = data.set_index("delivery_class").loc[["early", "on_time", "late"]]
    values = data["negative_review_rate"] * 100

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(["Early", "On time", "Late"], values)
    ax.set(
        title="Late delivery is strongly associated with negative reviews",
        ylabel="Negative review rate (%)",
    )
    return _save(fig, "cx_delivery_class.png")


def _delay_bands(data: pd.DataFrame) -> Path:
    data = data.sort_values("delay_band_sort")

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(
        range(len(data)),
        data["negative_review_rate"] * 100,
        marker="o",
    )
    ax.set_xticks(
        range(len(data)),
        [DELAY_LABELS[x] for x in data["delay_band"]],
        rotation=35,
        ha="right",
    )
    ax.set(
        title="Negative reviews rise as deliveries miss the promise",
        ylabel="Negative review rate (%)",
    )
    return _save(fig, "cx_delay_bands.png")


def _gmv_stratification(segments: pd.DataFrame) -> Path:
    data = segments[segments["segment_type"] == "gmv_band"].sort_values("segment_sort")
    x = range(len(data))

    fig, ax = plt.subplots(figsize=(9, 5))
    ax.bar(
        [i - 0.18 for i in x],
        data["early_negative_review_rate"] * 100,
        width=0.36,
        label="Early",
    )
    ax.bar(
        [i + 0.18 for i in x],
        data["late_negative_review_rate"] * 100,
        width=0.36,
        label="Late",
    )
    ax.set_xticks(list(x), ["< R$50", "R$50–99", "R$100–199", "R$200+"])
    ax.set(
        title="The delivery-review gap persists across order values",
        ylabel="Negative review rate (%)",
    )
    ax.legend()
    return _save(fig, "cx_gmv_stratification.png")


def _review_selection(data: pd.DataFrame) -> Path:
    data = data.set_index("review_availability")
    values = data.loc[["reviewed", "unreviewed"], "late_delivery_rate"] * 100

    fig, ax = plt.subplots(figsize=(7, 5))
    ax.bar(["Reviewed", "Unreviewed"], values)
    ax.set(
        title="Review availability is associated with delivery performance",
        ylabel="Late delivery rate (%)",
    )
    return _save(fig, "cx_review_selection.png")
