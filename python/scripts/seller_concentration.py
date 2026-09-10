"""Seller concentration analysis and watchlist outputs."""

from __future__ import annotations

from decimal import Decimal
from pathlib import Path

import matplotlib

#matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from python.scripts.config import ANALYSIS_OUTPUT_DIR, FIGURES_OUTPUT_DIR, SQL_DIR


def read_sql(conn, sql: str) -> pd.DataFrame:
    with conn.cursor() as cur:
        cur.execute(sql)
        frame = pd.DataFrame(cur.fetchall(), columns=[c[0] for c in cur.description])

    for col in frame.select_dtypes("object"):
        if frame[col].map(lambda x: isinstance(x, Decimal)).any():
            frame[col] = pd.to_numeric(frame[col], errors="coerce")
    return frame


def rebuild_extracts(conn) -> None:
    sql = (SQL_DIR / "analysis" / "seller_concentration.sql").read_text()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def load_extracts(conn) -> dict[str, pd.DataFrame]:
    queries = {
        "prioritization": """
            SELECT * FROM analysis.seller_prioritization
            ORDER BY contribution_row_number NULLS LAST, seller_id
        """,
        "watchlist": """
            SELECT * FROM analysis.seller_watchlist
            ORDER BY excess_late_marketplace DESC NULLS LAST, seller_id
        """,
        "volume_sensitivity": """
            SELECT * FROM analysis.seller_volume_threshold_sensitivity
            ORDER BY min_eligible_seller_orders
        """,
        "concentration": "SELECT * FROM analysis.contribution_concentration",
    }
    return {name: read_sql(conn, sql) for name, sql in queries.items()}


def export_extracts(frames: dict[str, pd.DataFrame]) -> list[Path]:
    ANALYSIS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    files = {
        "prioritization": "seller_prioritization.csv",
        "watchlist": "seller_watchlist.csv",
        "volume_sensitivity": "seller_volume_threshold_sensitivity.csv",
    }

    paths = []
    for name, filename in files.items():
        path = ANALYSIS_OUTPUT_DIR / filename
        frames[name].to_csv(path, index=False)
        paths.append(path)
    return paths


def seller_spot_checks(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        WITH source AS (
            SELECT
                seller_id,
                COUNT(*) FILTER (WHERE is_delivery_performance_eligible) AS eligible,
                COUNT(*) FILTER (WHERE is_late) AS late
            FROM metrics.kpi_seller_orders
            GROUP BY seller_id
        )
        SELECT
            p.seller_id,
            p.delivery_eligible_seller_orders AS table_eligible,
            s.eligible AS source_eligible,
            p.late_seller_orders AS table_late,
            s.late AS source_late,
            p.seller_late_rate,
            p.expected_late_marketplace,
            p.excess_late_marketplace
        FROM analysis.seller_prioritization p
        JOIN source s USING (seller_id)
        WHERE p.seller_id IN (
            '4a3ca9315b744ce9f8e9374361493884',
            '06a2c3af7b3aee5d69171b0e14f0ee87',
            '6560211a19b47992c3666cc44a7e94c0'
        )
        ORDER BY p.seller_id
        """,
    )


def write_validation_report(
    frames: dict[str, pd.DataFrame],
    spot_checks: pd.DataFrame,
) -> Path:
    sellers = frames["prioritization"]
    watch = frames["watchlist"]
    conc = frames["concentration"].iloc[0]

    eligible = sellers["delivery_eligible_seller_orders"]
    late = sellers["late_seller_orders"]
    expected = sellers["expected_late_marketplace"]
    excess = sellers["excess_late_marketplace"]

    rate_error = (
        sellers.loc[eligible > 0, "seller_late_rate"]
        - late[eligible > 0] / eligible[eligible > 0]
    ).abs().max()

    expected_error = (
        expected - eligible * sellers["marketplace_seller_late_rate"]
    ).abs().max()

    excess_error = (excess - (late - expected)).abs().max()

    lines = [
        "Seller concentration validation",
        "",
        f"Sellers with late orders: {int(conc['sellers_with_late_orders'])}",
        f"Sellers to 50% late units: {int(conc['sellers_to_50pct_late_units'])}",
        f"Sellers to 80% late units: {int(conc['sellers_to_80pct_late_units'])}",
        f"Contribution sum: {float(conc['contribution_sum']):.10f}",
        "",
        f"Max late-rate reconciliation error: {float(rate_error):.12f}",
        f"Max expected-late reconciliation error: {float(expected_error):.12f}",
        f"Max excess-late reconciliation error: {float(excess_error):.12f}",
        "",
        f"Watchlist sellers: {len(watch)}",
        f"High excess: {int(watch['is_high_excess'].sum())}",
        f"High rate + high volume: {int(watch['is_high_rate_high_volume'].sum())}",
        f"Recent deterioration: {int(watch['is_recently_deteriorating'].sum())}",
        "",
        "Seller spot checks",
    ]

    for row in spot_checks.itertuples():
        lines.append(
            f"{row.seller_id}: eligible {row.table_eligible}/{row.source_eligible}, "
            f"late {row.table_late}/{row.source_late}, "
            f"expected {row.expected_late_marketplace:.2f}, "
            f"excess {row.excess_late_marketplace:.2f}"
        )

    path = ANALYSIS_OUTPUT_DIR / "seller_concentration_validation.txt"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def make_figures(frames: dict[str, pd.DataFrame]) -> list[Path]:
    FIGURES_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sellers = frames["prioritization"].copy()

    return [
        _pareto(sellers),
        _rate_vs_volume(sellers),
        _top_excess(sellers),
    ]


def _save(fig, filename: str) -> Path:
    path = FIGURES_OUTPUT_DIR / filename
    fig.tight_layout()
    fig.savefig(path, dpi=140)
    plt.close(fig)
    return path


def _pareto(sellers: pd.DataFrame) -> Path:
    data = sellers[sellers["late_seller_orders"] > 0].sort_values(
        "contribution_row_number"
    )
    x = range(1, len(data) + 1)

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(x, data["cumulative_late_contribution"] * 100)
    ax.axhline(50, linestyle="--")
    ax.axhline(80, linestyle="--")
    ax.set(
        title="Late deliveries are concentrated among a relatively small seller group",
        xlabel="Sellers ranked by late seller-orders",
        ylabel="Cumulative share of late seller-orders (%)",
    )
    return _save(fig, "seller_pareto.png")


def _rate_vs_volume(sellers: pd.DataFrame) -> Path:
    data = sellers[sellers["delivery_eligible_seller_orders"] > 0].copy()
    benchmark = float(data["marketplace_seller_late_rate"].iloc[0])

    fig, ax = plt.subplots(figsize=(9, 5.5))
    ax.scatter(
        data["delivery_eligible_seller_orders"],
        data["seller_late_rate"] * 100,
        alpha=0.35,
    )

    watch = data[
        data["is_high_excess"]
        | data["is_high_rate_high_volume"]
        | data["is_recently_deteriorating"]
    ]
    ax.scatter(
        watch["delivery_eligible_seller_orders"],
        watch["seller_late_rate"] * 100,
    )

    ax.axhline(benchmark * 100, linestyle="--")
    ax.set_xscale("log")
    ax.set(
        title="High late rate alone is not enough: seller volume matters",
        xlabel="Eligible seller-orders (log scale)",
        ylabel="Seller late rate (%)",
    )
    return _save(fig, "seller_rate_vs_volume.png")


def _top_excess(sellers: pd.DataFrame) -> Path:
    top = (
        sellers[sellers["delivery_eligible_seller_orders"] >= 100]
        .nlargest(12, "excess_late_marketplace")
        .sort_values("excess_late_marketplace")
    )

    labels = [seller[:8] + "…" for seller in top["seller_id"]]

    fig, ax = plt.subplots(figsize=(9, 6))
    ax.barh(labels, top["excess_late_marketplace"])
    ax.set(
        title="Which sellers generate the most excess late orders?",
        xlabel="Excess late seller-orders vs marketplace benchmark",
        ylabel="Seller",
    )
    return _save(fig, "seller_excess_late.png")
