#!/usr/bin/env python3
"""Run data-quality investigation SQL and save the results."""

import subprocess
from pathlib import Path

from python.scripts.config import QUALITY_OUTPUT_DIR, SQL_DIR


INVESTIGATION_FILES = [
    "quality/08_review_anomalies.sql",
    "quality/09_missingness.sql",
    "quality/10_timestamp_validity.sql",
    "quality/11_status_consistency.sql",
    "quality/12_product_category.sql",
    "quality/13_geography.sql",
    "quality/14_monetary_reconciliation.sql",
    "quality/15_time_coverage.sql",
    "quality/16_treatment_impact.sql",
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
    QUALITY_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    combined = []

    for filename in INVESTIGATION_FILES:
        print(f"Running: {filename}")

        output = run_sql(filename)
        header = f"===== {filename} =====\n"
        result = header + output

        output_file = QUALITY_OUTPUT_DIR / f"{Path(filename).stem}.txt"
        output_file.write_text(result)

        combined.append(result)

    report_file = QUALITY_OUTPUT_DIR / "quality_investigation.txt"
    report_file.write_text("\n".join(combined))

    print(f"\nQuality investigation complete: {report_file}")


if __name__ == "__main__":
    main()