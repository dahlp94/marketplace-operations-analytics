"""Statistical validation of approved fulfillment and customer-experience findings."""

from __future__ import annotations

from decimal import Decimal
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from scipy.stats import norm

from python.scripts.config import ANALYSIS_OUTPUT_DIR, FIGURES_OUTPUT_DIR, SQL_DIR


SEED = 0
N_BOOT = 2000
Z95 = 1.959963984540054


def read_sql(conn, sql: str) -> pd.DataFrame:
    with conn.cursor() as cur:
        cur.execute(sql)
        frame = pd.DataFrame(cur.fetchall(), columns=[c[0] for c in cur.description])

    for col in frame.select_dtypes("object"):
        if frame[col].map(lambda x: isinstance(x, Decimal)).any():
            frame[col] = pd.to_numeric(frame[col], errors="coerce")
    return frame


def rebuild_extracts(conn) -> None:
    sql = (SQL_DIR / "analysis" / "statistical_validation.sql").read_text()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def load_extracts(conn) -> dict[str, pd.DataFrame]:
    return {
        "counts": read_sql(
            conn,
            "SELECT * FROM analysis.inference_rate_counts ORDER BY population",
        ),
        "orders": read_sql(
            conn,
            """
            SELECT
                order_id,
                is_comparable_trend_window,
                is_delivery_performance_eligible,
                delivery_class,
                is_late,
                delivery_delay_days,
                has_usable_review,
                is_negative_review,
                gmv_band,
                delay_severity,
                customer_state_group,
                category_group,
                is_multi_seller,
                is_repeat_order
            FROM analysis.inference_orders
            """,
        ),
    }


def wilson_ci(successes: int, n: int, z: float = Z95) -> tuple[float, float]:
    if n <= 0:
        return np.nan, np.nan

    p = successes / n
    z2 = z**2
    denom = 1 + z2 / n
    center = (p + z2 / (2 * n)) / denom
    margin = z * np.sqrt((p * (1 - p) + z2 / (4 * n)) / n) / denom
    return center - margin, center + margin


def diff_ci(
    s1: int, n1: int, s2: int, n2: int, z: float = Z95
) -> tuple[float, float, float, float]:
    p1, p2 = s1 / n1, s2 / n2
    diff = p1 - p2
    se = np.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    pvalue = 2 * norm.sf(abs(diff / se)) if se else np.nan
    return diff, diff - z * se, diff + z * se, pvalue


def rate_interval_table(
    counts: pd.DataFrame,
    *_unused,
) -> pd.DataFrame:
    rows = []
    for row in counts.itertuples():
        low, high = wilson_ci(int(row.numerator), int(row.denominator))
        rows.append(
            {
                "estimate": row.population,
                "grain": row.grain,
                "question": row.question,
                "numerator": int(row.numerator),
                "denominator": int(row.denominator),
                "rate": float(row.rate),
                "ci_low": low,
                "ci_high": high,
            }
        )
    return pd.DataFrame(rows)


def comparison_table(counts: pd.DataFrame) -> pd.DataFrame:
    idx = counts.set_index("population")
    specs = [
        (
            "late_vs_early_negative",
            "negative_review_late",
            "negative_review_early",
            "Late versus early negative-review gap",
        ),
        (
            "late_1_3_vs_early_negative",
            "negative_review_late_1_3",
            "negative_review_early",
            "1–3 day late versus early negative-review gap",
        ),
        (
            "unreviewed_vs_reviewed_late",
            "late_among_unreviewed_delivered",
            "late_among_reviewed_delivered",
            "Review-selection late-rate gap",
        ),
        (
            "feb_mar_2018_vs_early_baseline",
            "late_feb_mar_2018",
            "late_early_baseline",
            "February–March 2018 versus early-baseline late-rate gap",
        ),
        (
            "watchlist_vs_nonwatchlist",
            "watchlist_seller_order_late",
            "nonwatchlist_seller_order_late",
            "Watchlist versus non-watchlist seller late-rate gap",
        ),
    ]

    rows = []
    for name, left, right, question in specs:
        a, b = idx.loc[left], idx.loc[right]
        diff, low, high, pvalue = diff_ci(
            int(a.numerator),
            int(a.denominator),
            int(b.numerator),
            int(b.denominator),
        )
        rows.append(
            {
                "comparison": name,
                "question": question,
                "left_population": left,
                "right_population": right,
                "left_rate": float(a.rate),
                "right_rate": float(b.rate),
                "left_n": int(a.denominator),
                "right_n": int(b.denominator),
                "difference": diff,
                "ci_low": low,
                "ci_high": high,
                "p_value": pvalue,
            }
        )
    return pd.DataFrame(rows)


def model_population(orders: pd.DataFrame) -> pd.DataFrame:
    frame = orders[
        orders["is_delivery_performance_eligible"] & orders["has_usable_review"]
    ].copy()
    frame["y"] = frame["is_negative_review"].astype(int)
    frame["is_repeat_order"] = frame["is_repeat_order"].astype(int)
    frame["is_multi_seller"] = frame["is_multi_seller"].astype(int)
    return frame


def _bootstrap_diff(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    rng = np.random.default_rng(SEED)
    diffs = np.empty(N_BOOT)

    for i in range(N_BOOT):
        diffs[i] = (
            rng.choice(a, len(a), replace=True).mean()
            - rng.choice(b, len(b), replace=True).mean()
        )
    return diffs


def bootstrap_outputs(
    model_orders: pd.DataFrame,
    delivered: pd.DataFrame,
) -> pd.DataFrame:
    late = model_orders.loc[model_orders["delivery_class"] == "late", "y"].to_numpy()
    early = model_orders.loc[model_orders["delivery_class"] == "early", "y"].to_numpy()

    eligible = delivered[delivered["is_delivery_performance_eligible"]]
    reviewed_late = (
        eligible.loc[eligible["has_usable_review"], "is_late"].astype(int).to_numpy()
    )
    unreviewed_late = (
        eligible.loc[~eligible["has_usable_review"], "is_late"].astype(int).to_numpy()
    )

    specs = [
        (
            "late_minus_early_negative",
            _bootstrap_diff(late, early),
            "Late minus early negative-review rate",
        ),
        (
            "unreviewed_minus_reviewed_late",
            _bootstrap_diff(unreviewed_late, reviewed_late),
            "Unreviewed minus reviewed late-delivery rate",
        ),
    ]

    return pd.DataFrame(
        [
            {
                "quantity": name,
                "question": question,
                "n_bootstrap": N_BOOT,
                "seed": SEED,
                "point_estimate": float(np.mean(diffs)),
                "ci_low": float(np.percentile(diffs, 2.5)),
                "ci_high": float(np.percentile(diffs, 97.5)),
            }
            for name, diffs, question in specs
        ]
    )


MODEL_FORMULA = (
    "y ~ C(delay_severity, Treatment('early'))"
    " + C(gmv_band, Treatment('lt_50'))"
    " + C(customer_state_group, Treatment('SP'))"
    " + is_repeat_order"
    " + is_multi_seller"
)


def _fit(data: pd.DataFrame):
    return smf.logit(MODEL_FORMULA, data=data).fit(disp=False, maxiter=100)


def fit_models(model_orders: pd.DataFrame) -> tuple[pd.DataFrame, object]:
    result = _fit(model_orders)
    rows = []

    for level in (
        "on_time",
        "late_1_3",
        "late_4_7",
        "late_8_14",
        "late_15_30",
        "late_31plus",
    ):
        term = f"C(delay_severity, Treatment('early'))[T.{level}]"
        coef = float(result.params[term])
        low, high = result.conf_int().loc[term]
        rows.append(
            {
                "model": "delay_severity",
                "term": level,
                "n": len(model_orders),
                "odds_ratio": float(np.exp(coef)),
                "or_ci_low": float(np.exp(low)),
                "or_ci_high": float(np.exp(high)),
                "p_value": float(result.pvalues[term]),
                "reference": "early; GMV<50; SP",
            }
        )

    return pd.DataFrame(rows), result


def diagnostics(model_orders: pd.DataFrame, result) -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "n_model": len(model_orders),
                "n_negative": int(model_orders["y"].sum()),
                "negative_share": float(model_orders["y"].mean()),
                "n_late": int((model_orders["delivery_class"] == "late").sum()),
                "converged": bool(result.mle_retvals.get("converged", True)),
                "pseudo_r2": float(result.prsquared),
                "reference_categories": "early; GMV<50; SP",
                "note": (
                    "Unreviewed eligible orders are excluded because "
                    "negative-review outcome is undefined."
                ),
            }
        ]
    )


def sensitivity_table(
    model_orders: pd.DataFrame,
    delivered: pd.DataFrame,
) -> pd.DataFrame:
    p99 = model_orders["delivery_delay_days"].quantile(0.99)
    slices = {
        "all_reviewed_eligible": model_orders,
        "comparable_window": model_orders[model_orders["is_comparable_trend_window"]],
        "exclude_late_31plus": model_orders[model_orders["delivery_delay_days"] <= 30],
        "exclude_p99_delay": model_orders[model_orders["delivery_delay_days"] <= p99],
    }

    rows = []
    for name, frame in slices.items():
        late = frame[frame["delivery_class"] == "late"]["y"]
        early = frame[frame["delivery_class"] == "early"]["y"]
        rows.append(
            {
                "slice": name,
                "n": len(frame),
                "late_reviewed": len(late),
                "early_reviewed": len(early),
                "late_negative_rate": float(late.mean()),
                "early_negative_rate": float(early.mean()),
                "rate_difference": float(late.mean() - early.mean()),
            }
        )

    return pd.DataFrame(rows)


def missingness_table(orders: pd.DataFrame) -> pd.DataFrame:
    eligible = orders[orders["is_delivery_performance_eligible"]]

    rows = []
    for name, frame in (
        ("delivery_performance_eligible", eligible),
        ("reviewed_eligible_model", eligible[eligible["has_usable_review"]]),
        ("unreviewed_eligible_excluded", eligible[~eligible["has_usable_review"]]),
    ):
        rows.append(
            {
                "population": name,
                "orders": len(frame),
                "late_rate": float(frame["is_late"].mean()),
            }
        )
    return pd.DataFrame(rows)


def export_tables(tables: dict[str, pd.DataFrame]) -> list[Path]:
    ANALYSIS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    files = {
        "intervals": "review_effect_estimates.csv",
        "comparisons": "group_comparisons.csv",
        "bootstrap": "bootstrap_estimates.csv",
        "model": "review_outcome_model.csv",
        "diagnostics": "review_outcome_diagnostics.csv",
        "sensitivity": "statistical_sensitivity.csv",
        "missingness": "inference_missingness.csv",
    }

    paths = []
    for name, filename in files.items():
        path = ANALYSIS_OUTPUT_DIR / filename
        tables[name].to_csv(path, index=False)
        paths.append(path)
    return paths


def write_validation_report(tables: dict[str, pd.DataFrame]) -> Path:
    intervals = tables["intervals"].set_index("estimate")
    comparisons = tables["comparisons"].set_index("comparison")
    bootstrap = tables["bootstrap"].set_index("quantity")
    model = tables["model"].set_index("term")

    def rate(name: str) -> str:
        row = intervals.loc[name]
        return (
            f"{row.rate:.2%} "
            f"(95% CI {row.ci_low:.2%}–{row.ci_high:.2%}; n={row.denominator:,.0f})"
        )

    def gap(name: str) -> str:
        row = comparisons.loc[name]
        return f"{row.difference:.2%} (95% CI {row.ci_low:.2%}–{row.ci_high:.2%})"

    lines = [
        "Statistical validation",
        "",
        f"Seed={SEED}; bootstrap resamples={N_BOOT}",
        "",
        f"Comparable late rate: {rate('marketplace_late_comparable')}",
        f"Early negative-review rate: {rate('negative_review_early')}",
        f"Late negative-review rate: {rate('negative_review_late')}",
        "",
        f"Late vs early negative-review gap: {gap('late_vs_early_negative')}",
        f"1–3 day late vs early gap: {gap('late_1_3_vs_early_negative')}",
        f"Review-selection late-rate gap: {gap('unreviewed_vs_reviewed_late')}",
        f"Feb–Mar 2018 vs baseline late-rate gap: {gap('feb_mar_2018_vs_early_baseline')}",
        f"Watchlist vs non-watchlist late-rate gap: {gap('watchlist_vs_nonwatchlist')}",
        "",
        (
            "Bootstrap late-minus-early gap: "
            f"{bootstrap.loc['late_minus_early_negative', 'point_estimate']:.2%} "
            f"(95% CI {bootstrap.loc['late_minus_early_negative', 'ci_low']:.2%}–"
            f"{bootstrap.loc['late_minus_early_negative', 'ci_high']:.2%})"
        ),
        "",
        (
            "Adjusted odds ratio, 1–3 days late vs early: "
            f"{model.loc['late_1_3', 'odds_ratio']:.2f} "
            f"(95% CI {model.loc['late_1_3', 'or_ci_low']:.2f}–"
            f"{model.loc['late_1_3', 'or_ci_high']:.2f})"
        ),
        "Interpretation: adjusted association, not a causal effect.",
    ]

    path = ANALYSIS_OUTPUT_DIR / "statistical_validation.txt"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def make_figures(tables: dict[str, pd.DataFrame]) -> list[Path]:
    FIGURES_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    return [
        _group_differences(tables["comparisons"]),
        _model_odds(tables["model"]),
    ]


def _save(fig, filename: str) -> Path:
    path = FIGURES_OUTPUT_DIR / filename
    fig.tight_layout()
    fig.savefig(path, dpi=140)
    plt.close(fig)
    return path


def _group_differences(comparisons: pd.DataFrame) -> Path:
    labels = {
        "late_vs_early_negative": "Late − early negative",
        "late_1_3_vs_early_negative": "1–3 day late − early negative",
        "unreviewed_vs_reviewed_late": "Unreviewed − reviewed late",
        "feb_mar_2018_vs_early_baseline": "Feb–Mar 2018 − baseline late",
        "watchlist_vs_nonwatchlist": "Watchlist − non-watchlist late",
    }

    data = comparisons.set_index("comparison").loc[list(labels)].iloc[::-1]
    y = range(len(data))

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.errorbar(
        data["difference"] * 100,
        y,
        xerr=[
            (data["difference"] - data["ci_low"]) * 100,
            (data["ci_high"] - data["difference"]) * 100,
        ],
        fmt="o",
        capsize=3,
    )
    ax.axvline(0, linewidth=0.8)
    ax.set_yticks(list(y), [labels[i] for i in data.index])
    ax.set(
        xlabel="Difference (percentage points)",
        title="Key differences with 95% confidence intervals",
    )
    return _save(fig, "stat_group_differences.png")


def _model_odds(model: pd.DataFrame) -> Path:
    labels = {
        "on_time": "On time",
        "late_1_3": "1–3 days late",
        "late_4_7": "4–7 days late",
        "late_8_14": "8–14 days late",
        "late_15_30": "15–30 days late",
        "late_31plus": "31+ days late",
    }

    data = model.set_index("term").loc[list(labels)].iloc[::-1]
    y = range(len(data))

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.errorbar(
        data["odds_ratio"],
        y,
        xerr=[
            data["odds_ratio"] - data["or_ci_low"],
            data["or_ci_high"] - data["odds_ratio"],
        ],
        fmt="o",
        capsize=3,
    )
    ax.axvline(1, linewidth=0.8)
    ax.set_yticks(list(y), [labels[i] for i in data.index])
    ax.set(
        xlabel="Adjusted odds ratio vs early delivery",
        title="Delay severity and negative-review odds",
    )
    return _save(fig, "stat_model_odds_ratios.png")
