"""Fulfillment root-cause extracts, validation checks, and figures.

Uses certified metrics.* and analysis.* fields. Delivery classifications and
component durations are not recalculated except in explicit spot checks.
"""

from __future__ import annotations

from decimal import Decimal
from pathlib import Path

import matplotlib

#matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from python.scripts.config import ANALYSIS_OUTPUT_DIR, FIGURES_OUTPUT_DIR, SQL_DIR


COMPARABLE_LABEL = "2017-02-01 through 2018-08-31"


# ---------------------------------------------------------------------------
# Database / extract helpers
# ---------------------------------------------------------------------------

def read_sql(conn, sql: str) -> pd.DataFrame:
    """Run SQL and return a DataFrame with PostgreSQL numerics coerced."""
    with conn.cursor() as cursor:
        cursor.execute(sql)
        frame = pd.DataFrame(cursor.fetchall(), columns=[c[0] for c in cursor.description])

    for column in frame.select_dtypes(include="object"):
        if frame[column].map(lambda value: isinstance(value, Decimal)).any():
            frame[column] = pd.to_numeric(frame[column], errors="coerce")
    return frame


def rebuild_extracts(conn) -> None:
    sql = (SQL_DIR / "analysis" / "fulfillment_root_cause.sql").read_text()
    with conn.cursor() as cursor:
        cursor.execute(sql)
    conn.commit()


def load_extracts(conn) -> dict[str, pd.DataFrame]:
    queries = {
        "fulfillment_month": """
            SELECT * FROM analysis.fulfillment_month
            ORDER BY purchase_month
        """,
        "fulfillment_decomposition": """
            SELECT * FROM analysis.fulfillment_decomposition
            ORDER BY analysis_period, delivery_class
        """,
        "segment_performance": """
            SELECT * FROM analysis.segment_fulfillment_performance
            ORDER BY segment_type, late_units DESC NULLS LAST, segment_key
        """,
        "segment_month": """
            SELECT * FROM analysis.segment_fulfillment_month
            ORDER BY segment_type, segment_key, purchase_month
        """,
    }
    return {name: read_sql(conn, sql) for name, sql in queries.items()}


def export_extracts(frames: dict[str, pd.DataFrame]) -> dict[str, Path]:
    ANALYSIS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    filenames = {
        "fulfillment_month": "fulfillment_trends.csv",
        "fulfillment_decomposition": "fulfillment_decomposition.csv",
        "segment_performance": "segment_delivery_performance.csv",
        "segment_month": "segment_fulfillment_month.csv",
    }

    written = {}
    for name, filename in filenames.items():
        path = ANALYSIS_OUTPUT_DIR / filename
        frames[name].to_csv(path, index=False)
        written[name] = path
    return written


# ---------------------------------------------------------------------------
# Validation / sensitivity queries
# ---------------------------------------------------------------------------

def outlier_sensitivity(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        WITH bounds AS (
            SELECT
                PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY seller_handling_days) AS handling_p99,
                PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY carrier_transit_days) AS transit_p99,
                PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY delivery_delay_days) AS delay_p99
            FROM metrics.kpi_orders
            WHERE is_comparable_trend_window
              AND is_delivery_performance_eligible
        ),
        base AS (
            SELECT o.*, b.*
            FROM metrics.kpi_orders o
            CROSS JOIN bounds b
            WHERE o.is_comparable_trend_window
              AND o.is_delivery_performance_eligible
        ),
        slices AS (
            SELECT 'all_comparable' AS slice, * FROM base
            UNION ALL
            SELECT 'exclude_p99_transit', * FROM base
            WHERE carrier_transit_days IS NULL OR carrier_transit_days <= transit_p99
            UNION ALL
            SELECT 'exclude_p99_handling', * FROM base
            WHERE seller_handling_days IS NULL OR seller_handling_days <= handling_p99
            UNION ALL
            SELECT 'exclude_p99_delay', * FROM base
            WHERE delivery_delay_days <= delay_p99
        )
        SELECT
            slice,
            COUNT(*)::INTEGER AS eligible_orders,
            COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_count,
            COUNT(*) FILTER (WHERE is_late)::NUMERIC / NULLIF(COUNT(*), 0) AS late_delivery_rate,
            AVG(seller_handling_days) AS avg_seller_handling_days,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY seller_handling_days) AS median_seller_handling_days,
            AVG(carrier_transit_days) AS avg_carrier_transit_days,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY carrier_transit_days) AS median_carrier_transit_days
        FROM slices
        GROUP BY slice
        ORDER BY CASE slice
            WHEN 'all_comparable' THEN 1
            WHEN 'exclude_p99_transit' THEN 2
            WHEN 'exclude_p99_handling' THEN 3
            ELSE 4
        END
        """,
    )


def monthly_outlier_sensitivity(conn) -> pd.DataFrame:
    frame = read_sql(
        conn,
        """
        WITH bounds AS (
            SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY carrier_transit_days) AS transit_p99
            FROM metrics.kpi_orders
            WHERE is_comparable_trend_window
              AND is_carrier_transit_eligible
        )
        SELECT
            purchase_month,
            COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::INTEGER AS eligible_orders,
            COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_count,
            COUNT(*) FILTER (WHERE is_late)::NUMERIC
                / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0) AS late_delivery_rate,
            COUNT(*) FILTER (
                WHERE is_delivery_performance_eligible
                  AND (carrier_transit_days IS NULL OR carrier_transit_days <= transit_p99)
            )::INTEGER AS eligible_ex_p99_transit,
            COUNT(*) FILTER (
                WHERE is_late
                  AND (carrier_transit_days IS NULL OR carrier_transit_days <= transit_p99)
            )::INTEGER AS late_ex_p99_transit
        FROM metrics.kpi_orders
        CROSS JOIN bounds
        WHERE is_comparable_trend_window
        GROUP BY purchase_month
        ORDER BY purchase_month
        """,
    )
    frame["late_rate_ex_p99_transit"] = (
        frame["late_ex_p99_transit"] / frame["eligible_ex_p99_transit"]
    )
    return frame


def quarterly_aggregation(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        SELECT
            DATE_TRUNC('quarter', purchase_month)::date AS purchase_quarter,
            SUM(delivery_performance_eligible)::INTEGER AS delivery_performance_eligible,
            SUM(late_count)::INTEGER AS late_count,
            SUM(late_count)::NUMERIC / NULLIF(SUM(delivery_performance_eligible), 0) AS late_delivery_rate,
            SUM(late_gmv) AS late_gmv,
            AVG(median_carrier_transit_days) AS avg_of_monthly_median_transit
        FROM analysis.fulfillment_month
        WHERE is_comparable_trend_window
        GROUP BY 1
        ORDER BY 1
        """,
    )


def weekly_around_spikes(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        SELECT
            DATE_TRUNC('week', purchase_date)::date AS purchase_week,
            COUNT(*) FILTER (WHERE is_delivery_performance_eligible)::INTEGER AS delivery_performance_eligible,
            COUNT(*) FILTER (WHERE is_late)::INTEGER AS late_count,
            COUNT(*) FILTER (WHERE is_late)::NUMERIC
                / NULLIF(COUNT(*) FILTER (WHERE is_delivery_performance_eligible), 0) AS late_delivery_rate,
            AVG(seller_handling_days) AS avg_seller_handling_days,
            AVG(carrier_transit_days) AS avg_carrier_transit_days,
            AVG(promised_window_days) AS avg_promised_window_days
        FROM metrics.kpi_orders
        WHERE purchase_date >= DATE '2017-10-01'
          AND purchase_date < DATE '2018-05-01'
        GROUP BY 1
        ORDER BY 1
        """,
    )


def extreme_delay_orders(conn, limit: int = 15) -> pd.DataFrame:
    return read_sql(
        conn,
        f"""
        SELECT
            order_id,
            purchase_date,
            delivery_class,
            delivery_delay_days,
            seller_handling_days,
            carrier_transit_days,
            promised_window_days,
            purchase_to_delivery_days,
            gmv
        FROM metrics.kpi_orders
        WHERE is_comparable_trend_window
          AND is_delivery_performance_eligible
        ORDER BY delivery_delay_days DESC NULLS LAST
        LIMIT {int(limit)}
        """,
    )


def order_component_spot_checks(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        WITH ranked AS (
            SELECT
                o.*,
                ROW_NUMBER() OVER (
                    PARTITION BY delivery_class, purchase_month
                    ORDER BY order_id
                ) AS rn
            FROM metrics.kpi_orders o
            WHERE is_comparable_trend_window
              AND is_delivery_performance_eligible
              AND delivery_class IN ('late', 'early')
              AND purchase_month IN (
                  DATE '2017-08-01', DATE '2017-11-01',
                  DATE '2018-03-01', DATE '2018-08-01'
              )
        )
        SELECT
            r.order_id,
            r.purchase_month,
            r.delivery_class,
            r.seller_handling_days AS kpi_seller_handling_days,
            CASE WHEN r.is_seller_handling_eligible THEN
                EXTRACT(EPOCH FROM (f.order_delivered_carrier_date - f.order_approved_at)) / 86400.0
            END AS source_seller_handling_days,
            r.carrier_transit_days AS kpi_carrier_transit_days,
            CASE WHEN r.is_carrier_transit_eligible THEN
                EXTRACT(EPOCH FROM (f.order_delivered_customer_date - f.order_delivered_carrier_date)) / 86400.0
            END AS source_carrier_transit_days,
            r.delivery_delay_days AS kpi_delivery_delay_days,
            f.order_delivered_customer_date::date - f.order_estimated_delivery_date::date AS source_delivery_delay_days,
            r.purchase_to_delivery_days AS kpi_purchase_to_delivery_days,
            r.promised_window_days AS kpi_promised_window_days,
            r.is_seller_handling_eligible,
            r.is_carrier_transit_eligible
        FROM ranked r
        JOIN analytics.fact_orders f USING (order_id)
        WHERE r.rn = 1
        ORDER BY r.purchase_month, r.delivery_class
        """,
    )


def seller_descriptive_snapshot(conn) -> pd.DataFrame:
    return read_sql(
        conn,
        """
        SELECT
            seller_id,
            delivery_eligible_seller_orders,
            late_seller_orders,
            seller_late_rate,
            seller_late_contribution,
            seller_gmv,
            seller_late_gmv,
            delivery_eligible_seller_orders < 30 AS is_low_sample
        FROM analysis.seller_contribution
        ORDER BY contribution_row_number
        """,
    )


# ---------------------------------------------------------------------------
# Validation report
# ---------------------------------------------------------------------------

def _max_abs_difference(frame: pd.DataFrame, left: str, right: str) -> float:
    return float((frame[left] - frame[right]).abs().max())


def write_validation_report(
    frames: dict[str, pd.DataFrame],
    sensitivity: pd.DataFrame,
    monthly_sensitivity: pd.DataFrame,
    quarterly: pd.DataFrame,
    weekly: pd.DataFrame,
    spot_checks: pd.DataFrame,
    extremes: pd.DataFrame,
) -> Path:
    month = frames["fulfillment_month"]
    comparable = month[month["is_comparable_trend_window"]]
    decomp = frames["fulfillment_decomposition"]
    decomp = decomp[decomp["analysis_period"] == "comparable_trend_window"]

    eligible = int(comparable["delivery_performance_eligible"].sum())
    late = int(comparable["late_count"].sum())

    lines = [
        "Fulfillment root-cause validation",
        "",
        f"Analysis period: {COMPARABLE_LABEL}",
        "Coverage class: analysis.reporting_month.full_comparable",
        "Source: certified metrics.kpi_orders / analysis.* extracts",
        "",
        "Comparable-window totals",
        f"  eligible orders: {eligible}",
        f"  late orders: {late}",
        f"  late rate: {late / eligible:.6f}",
        f"  late GMV: {float(comparable['late_gmv'].sum()):.2f}",
        "",
        "Component populations remain separate",
        f"  handling-eligible month sum: {int(comparable['seller_handling_eligible'].sum())}",
        f"  transit-eligible month sum: {int(comparable['carrier_transit_eligible'].sum())}",
        "",
        "Delivery-class decomposition (comparable window)",
    ]

    for _, row in decomp.sort_values("delivery_class").iterrows():
        lines.append(
            f"  {row['delivery_class']}: n={int(row['eligible_orders'])} "
            f"median handling={row['median_seller_handling_days']:.3f} "
            f"median transit={row['median_carrier_transit_days']:.3f} "
            f"median promise={row['median_promised_window_days']:.1f}"
        )

    lines += ["", "Outlier sensitivity (comparable window)"]
    for _, row in sensitivity.iterrows():
        lines.append(
            f"  {row['slice']}: late {int(row['late_count'])} / "
            f"{int(row['eligible_orders'])} = {row['late_delivery_rate']:.6f}"
        )

    spike_months = monthly_sensitivity[
        monthly_sensitivity["purchase_month"].astype(str).str[:7].isin(
            ["2017-11", "2018-02", "2018-03", "2018-08"]
        )
    ]
    lines += ["", "Spike months with and without p99 transit"]
    for _, row in spike_months.iterrows():
        lines.append(
            f"  {pd.Timestamp(row['purchase_month']).date()}: "
            f"{row['late_delivery_rate']:.4f} vs "
            f"{row['late_rate_ex_p99_transit']:.4f} excluding p99 transit"
        )

    lines += ["", "Quarterly late rate (comparable window)"]
    for _, row in quarterly.iterrows():
        lines.append(
            f"  {pd.Timestamp(row['purchase_quarter']).date()}: "
            f"{int(row['late_count'])} / {int(row['delivery_performance_eligible'])} "
            f"= {row['late_delivery_rate']:.4f}"
        )

    peak = weekly.loc[weekly["late_delivery_rate"].idxmax()]
    lines += [
        "",
        "Weekly peak inside Oct 2017-Apr 2018",
        f"  week {pd.Timestamp(peak['purchase_week']).date()}: "
        f"{int(peak['late_count'])} / {int(peak['delivery_performance_eligible'])} "
        f"= {peak['late_delivery_rate']:.4f}",
        "",
        "Order-level component spot checks versus analytics.fact_orders",
        f"  rows: {len(spot_checks)}",
        f"  max abs handling difference: {_max_abs_difference(spot_checks, 'kpi_seller_handling_days', 'source_seller_handling_days'):.12f}",
        f"  max abs transit difference: {_max_abs_difference(spot_checks, 'kpi_carrier_transit_days', 'source_carrier_transit_days'):.12f}",
        f"  max abs delay difference: {_max_abs_difference(spot_checks, 'kpi_delivery_delay_days', 'source_delivery_delay_days'):.12f}",
        "",
        "Largest comparable-window delays remain transit-dominated",
    ]

    for _, row in extremes.head(5).iterrows():
        lines.append(
            f"  {row['order_id']}: delay={int(row['delivery_delay_days'])}d "
            f"handling={row['seller_handling_days']:.2f} "
            f"transit={row['carrier_transit_days']:.2f}"
        )

    path = ANALYSIS_OUTPUT_DIR / "fulfillment_root_cause_validation.txt"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


# ---------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------

def _save_figure(fig, filename: str) -> Path:
    path = FIGURES_OUTPUT_DIR / filename
    fig.tight_layout()
    fig.savefig(path, dpi=140)
    plt.close(fig)
    return path


def _month_axis(ax, frame: pd.DataFrame) -> None:
    labels = frame["month_label"].tolist()
    x = list(range(len(labels)))
    ax.set_xlabel("Purchase month (comparable window)")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=45, ha="right")


def _monthly_line_chart(
    frame: pd.DataFrame,
    series: list[tuple[str, str]],
    title: str,
    ylabel: str,
    filename: str,
    horizontal_zero: bool = False,
) -> Path:
    x = list(range(len(frame)))
    fig, ax = plt.subplots(figsize=(11, 5.5))

    for column, label in series:
        ax.plot(x, frame[column].astype(float), marker="o", label=label)

    if horizontal_zero:
        ax.axhline(0, linewidth=0.8)

    _month_axis(ax, frame)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.legend()
    return _save_figure(fig, filename)


def make_figures(frames: dict[str, pd.DataFrame]) -> list[Path]:
    FIGURES_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    month = frames["fulfillment_month"].copy()
    month["purchase_month"] = pd.to_datetime(month["purchase_month"])
    comparable = month[month["is_comparable_trend_window"]].sort_values("purchase_month").copy()
    comparable["month_label"] = comparable["purchase_month"].dt.strftime("%Y-%m")

    decomp = frames["fulfillment_decomposition"]
    decomp = decomp[decomp["analysis_period"] == "comparable_trend_window"].copy()

    return [
        _late_rate_trend(comparable),
        _handling_vs_transit(comparable),
        _promise_vs_fulfillment(comparable),
        _component_by_class(decomp),
        _geography_late_rate(frames["segment_performance"]),
        _delay_components(comparable),
    ]


def _late_rate_trend(frame: pd.DataFrame) -> Path:
    x = list(range(len(frame)))
    fig, ax = plt.subplots(figsize=(11, 5.5))
    ax2 = ax.twinx()

    ax.plot(x, frame["late_delivery_rate"].astype(float) * 100, marker="o", label="Late rate")
    ax2.bar(x, frame["late_count"].astype(float), alpha=0.3, label="Late orders")

    _month_axis(ax, frame)
    ax.set_ylabel("Late delivery rate (%)")
    ax2.set_ylabel("Late eligible orders")
    ax.set_title("Late delivery rate and volume over time")

    line_handles, line_labels = ax.get_legend_handles_labels()
    bar_handles, bar_labels = ax2.get_legend_handles_labels()
    ax.legend(line_handles + bar_handles, line_labels + bar_labels, loc="upper left")

    return _save_figure(fig, "late_rate_trend.png")


def _handling_vs_transit(frame: pd.DataFrame) -> Path:
    return _monthly_line_chart(
        frame,
        [
            ("median_seller_handling_days", "Median seller handling"),
            ("median_carrier_transit_days", "Median carrier transit"),
        ],
        "Seller handling and carrier transit over time",
        "Median days",
        "handling_vs_transit.png",
    )


def _promise_vs_fulfillment(frame: pd.DataFrame) -> Path:
    return _monthly_line_chart(
        frame,
        [
            ("median_promised_window_days", "Median promised window"),
            ("median_purchase_to_delivery_days", "Median purchase-to-delivery"),
        ],
        "Promised window versus actual fulfillment time",
        "Median days",
        "promise_vs_fulfillment.png",
    )


def _component_by_class(frame: pd.DataFrame) -> Path:
    order = ["early", "on_time", "late"]
    frame = frame.set_index("delivery_class").reindex(order).reset_index()
    x = list(range(len(order)))
    width = 0.25

    metrics = [
        ("median_seller_handling_days", "Seller handling"),
        ("median_carrier_transit_days", "Carrier transit"),
        ("median_promised_window_days", "Promised window"),
    ]

    fig, ax = plt.subplots(figsize=(10, 5.5))
    for offset, (column, label) in enumerate(metrics, start=-1):
        ax.bar([pos + offset * width for pos in x], frame[column], width=width, label=label)

    ax.set_xticks(x)
    ax.set_xticklabels(
        [f"{row.delivery_class}\n(n={int(row.eligible_orders):,})" for row in frame.itertuples()]
    )
    ax.set_ylabel("Median days")
    ax.set_title("Fulfillment components by delivery class")
    ax.legend()
    return _save_figure(fig, "component_by_delivery_class.png")


def _geography_late_rate(segments: pd.DataFrame) -> Path:
    states = segments[
        (segments["segment_type"] == "customer_state") & (~segments["is_low_sample"])
    ].copy()

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.scatter(
        states["eligible_units"],
        states["late_rate"] * 100,
        s=states["late_units"].clip(lower=20) * 0.6,
        alpha=0.75,
    )

    for row in states.itertuples():
        if row.late_units >= 150 or row.late_rate >= 0.12:
            ax.annotate(
                row.segment_key,
                (row.eligible_units, row.late_rate * 100),
                xytext=(5, 4),
                textcoords="offset points",
                fontsize=8,
            )

    ax.set_xlabel("Eligible orders in the comparable window")
    ax.set_ylabel("Late delivery rate (%)")
    ax.set_title("Late delivery rate by customer state")
    return _save_figure(fig, "geography_late_rate.png")


def _delay_components(frame: pd.DataFrame) -> Path:
    return _monthly_line_chart(
        frame,
        [
            ("median_delivery_delay_days", "Median delivery delay"),
            ("p90_delivery_delay_days", "90th-percentile delay"),
        ],
        "Delivery delay distribution over time",
        "Calendar days versus promise",
        "delay_distribution.png",
        horizontal_zero=True,
    )
