#!/usr/bin/env python3
"""Run independent metric-layer validation SQL and save the results."""

import subprocess
from pathlib import Path

from python.scripts.config import METRIC_LAYER_OUTPUT_DIR, SQL_DIR


VALIDATION_FILES = [
    "metrics/validate/01_independent_spot_checks.sql",
    "metrics/validate/02_grain_and_reconciliation.sql",
]


def run_sql(filename):
    result = subprocess.run(
        [
            "psql",
            "-v", "ON_ERROR_STOP=1",
            "-P", "pager=off",
            "-f", str(SQL_DIR / filename),
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"{filename} failed:\n{result.stderr}"
        )

    return result.stdout


def main():
    METRIC_LAYER_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    combined = []

    for filename in VALIDATION_FILES:
        print(f"Running: {filename}")

        output = run_sql(filename)
        result = f"===== {filename} =====\n{output}"

        output_file = (
            METRIC_LAYER_OUTPUT_DIR
            / f"{Path(filename).stem}.txt"
        )
        output_file.write_text(result, encoding="utf-8")
        combined.append(result)

    report_file = METRIC_LAYER_OUTPUT_DIR / "metric_layer_validation.txt"
    report_file.write_text("\n".join(combined), encoding="utf-8")

    print(f"\nMetric-layer validation complete: {report_file}")


if __name__ == "__main__":
    main()
