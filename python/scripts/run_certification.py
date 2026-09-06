#!/usr/bin/env python3
"""Run certification SQL and save the results."""

import subprocess
from pathlib import Path

from python.scripts.config import CERTIFICATION_OUTPUT_DIR, SQL_DIR

CERTIFICATION_FILES = [
    "certification/01_source_reconciliation.sql",
    "certification/02_monetary_reconciliation.sql",
    "certification/03_treatment_recalculation.sql",
    "certification/04_sample_lineage.sql",
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
    CERTIFICATION_OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    combined = []

    for filename in CERTIFICATION_FILES:
        print(f"Running: {filename}")

        output = run_sql(filename)
        result = f"===== {filename} =====\n{output}"

        output_file = (
            CERTIFICATION_OUTPUT_DIR
            / f"{Path(filename).stem}.txt"
        )
        output_file.write_text(
            result,
            encoding="utf-8",
        )

        combined.append(result)

    report_file = (
        CERTIFICATION_OUTPUT_DIR
        / "certification.txt"
    )
    report_file.write_text(
        "\n".join(combined),
        encoding="utf-8",
    )

    print(
        f"\nCertification complete: {report_file}"
    )

if __name__ == "__main__":
    main()
