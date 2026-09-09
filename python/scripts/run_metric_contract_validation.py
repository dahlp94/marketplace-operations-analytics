#!/usr/bin/env python3

"""Run metric validation SQL files and save the results."""

import subprocess
from pathlib import Path

from python.scripts.config import METRIC_VALIDATION_OUTPUT_DIR, SQL_DIR


SQL_FILES = [
    "metrics/01_metric_populations.sql",
    "metrics/02_metric_contract_prototypes.sql",
    "metrics/03_metric_validation_examples.sql",
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
        check=True,
    )
    return result.stdout


def main():
    METRIC_VALIDATION_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    results = []

    for filename in SQL_FILES:
        print(f"Running {filename}")

        output = run_sql(filename)
        results.append(f"===== {filename} =====\n{output}")

        output_path = METRIC_VALIDATION_OUTPUT_DIR / f"{Path(filename).stem}.txt"
        output_path.write_text(output, encoding="utf-8")

    report_path = METRIC_VALIDATION_OUTPUT_DIR / "metric_validation.txt"
    report_path.write_text("\n".join(results), encoding="utf-8")

    print(f"Validation complete: {report_path}")


if __name__ == "__main__":
    main()