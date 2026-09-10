#!/usr/bin/env python3
"""Run analysis-layer validation SQL and save the results."""

import subprocess
from pathlib import Path

from python.scripts.config import ANALYSIS_OUTPUT_DIR, SQL_DIR

VALIDATION_FILES = [
    "analysis/validate/01_window_spot_checks.sql",
    "analysis/validate/02_rank_contribution_segments.sql",
    "analysis/validate/03_fulfillment_root_cause.sql",
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
    ANALYSIS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    combined = []

    for filename in VALIDATION_FILES:
        print(f"Running: {filename}")

        output = run_sql(filename)
        result = f"===== {filename} =====\n{output}"

        output_file = ANALYSIS_OUTPUT_DIR / f"{Path(filename).stem}.txt"
        output_file.write_text(result, encoding="utf-8")
        combined.append(result)

    report_file = ANALYSIS_OUTPUT_DIR / "analysis_validation.txt"
    report_file.write_text("\n".join(combined), encoding="utf-8")

    print(f"\nAnalysis validation complete: {report_file}")

if __name__ == "__main__":
    main()
