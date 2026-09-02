#!/usr/bin/env python3

"""Run the source SQL audits and save the results."""

import subprocess
from pathlib import Path

from python.scripts.config import OUTPUT_DIR, SQL_DIR


AUDIT_FILES = [
    "raw/02_row_counts.sql",
    "quality/01_key_uniqueness.sql",
    "quality/02_null_profiling.sql",
    "quality/03_fk_coverage.sql",
    "quality/04_cardinality.sql",
    "quality/05_customer_identity.sql",
    "quality/06_join_fanout.sql",
    "quality/07_sample_order_lineage.sql",
]


def run_sql(filename):
    result = subprocess.run(
        [
            "psql",
            "-v",
            "ON_ERROR_STOP=1",
            "-P",
            "pager=off",
            "-f",
            str(SQL_DIR / filename),
        ],
        capture_output=True,
        text=True,
        check=True,
    )

    return result.stdout


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    combined = []

    for filename in AUDIT_FILES:
        print(f"Running: {filename}")

        output = run_sql(filename)

        header = f"===== {filename} =====\n"
        result = header + output

        output_file = OUTPUT_DIR / f"{Path(filename).stem}.txt"
        output_file.write_text(result)

        combined.append(result)

    audit_file = OUTPUT_DIR / "source_audit.txt"
    audit_file.write_text("\n".join(combined))

    print(f"\nSource audit complete: {audit_file}")


if __name__ == "__main__":
    main()
