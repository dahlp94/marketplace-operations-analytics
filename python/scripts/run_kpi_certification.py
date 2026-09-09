#!/usr/bin/env python3
"""Run independent KPI certification SQL and save the results."""

import os
import subprocess
from pathlib import Path

from python.scripts.config import KPI_CERTIFICATION_OUTPUT_DIR, SQL_DIR


CERTIFICATION_FILES = [
    "kpi_certification/01_independent_marketplace.sql",
    "kpi_certification/02_seller_category_geography.sql",
    "kpi_certification/03_windows_rankings_customers.sql",
    "kpi_certification/04_structural_qa.sql",
    "kpi_certification/05_query_plans.sql",
]


def run_sql(filename):
    result = subprocess.run(
        [
            "psql",
            "-h", os.getenv("PGHOST", "127.0.0.1"),
            "-p", os.getenv("PGPORT", "55432"),
            "-U", os.getenv("PGUSER", "marketplace"),
            "-d", os.getenv("PGDATABASE", "marketplace_ops"),
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
    KPI_CERTIFICATION_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    combined = []

    for filename in CERTIFICATION_FILES:
        print(f"Running: {filename}")

        output = run_sql(filename)
        result = f"===== {filename} =====\n{output}"

        output_file = (
            KPI_CERTIFICATION_OUTPUT_DIR
            / f"{Path(filename).stem}.txt"
        )
        output_file.write_text(result, encoding="utf-8")
        combined.append(result)

    report_file = KPI_CERTIFICATION_OUTPUT_DIR / "kpi_certification.txt"
    report_file.write_text("\n".join(combined), encoding="utf-8")

    print(f"\nKPI certification complete: {report_file}")


if __name__ == "__main__":
    main()
