#!/usr/bin/env python3
"""Run analytical-model validation SQL and save the results."""

import subprocess
from pathlib import Path

from python.scripts.config import MODEL_OUTPUT_DIR, SQL_DIR


VALIDATION_FILES = [
    "analytics/validate/01_uniqueness.sql",
    "analytics/validate/02_referential_integrity.sql",
    "analytics/validate/03_geography_joins.sql",
    "analytics/validate/04_fanout_protection.sql",
    "analytics/validate/05_sample_lineage.sql",
    "analytics/validate/06_coverage_and_treatments.sql",
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
    MODEL_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    combined = []

    for filename in VALIDATION_FILES:
        print(f"Running: {filename}")

        output = run_sql(filename)
        header = f"===== {filename} =====\n"
        result = header + output

        output_file = MODEL_OUTPUT_DIR / f"{Path(filename).stem}.txt"
        output_file.write_text(result, encoding="utf-8")

        combined.append(result)

    report_file = MODEL_OUTPUT_DIR / "model_validation.txt"
    report_file.write_text(
        "\n".join(combined),
        encoding="utf-8",
    )

    print(f"\nModel validation complete: {report_file}")


if __name__ == "__main__":
    main()