#!/usr/bin/env python3
"""Build analysis layer from certified metrics tables."""

from python.scripts.config import SQL_DIR, connect

ANALYSIS_FILES = [
    "analysis/00_create_schema.sql",
    "analysis/01_reporting_periods.sql",
    "analysis/10_trends.sql",
    "analysis/11_rolling_windows.sql",
    "analysis/20_seller_positioning.sql",
    "analysis/22_category_cohorts.sql",
    "analysis/30_segments.sql",
    "analysis/40_constraints.sql",
]

def run_sql(cursor, filename):
    sql = (SQL_DIR / filename).read_text()
    cursor.execute(sql)

def main():
    with connect() as conn:
        with conn.cursor() as cursor:
            print("Building analysis layer")

            for filename in ANALYSIS_FILES:
                print(f"  {filename}")
                run_sql(cursor, filename)

    print("\nAnalysis layer rebuild complete.")


if __name__ == "__main__":
    main()
