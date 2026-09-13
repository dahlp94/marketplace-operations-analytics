#!/usr/bin/env python3
"""Build dashboard-ready views from certified metric and analysis tables."""

from python.scripts.config import SQL_DIR, connect


DASHBOARD_FILES = [
    "dashboard/00_create_schema.sql",
    "dashboard/executive_overview.sql",
    "dashboard/fulfillment_trends.sql",
    "dashboard/seller_performance.sql",
    "dashboard/category_performance.sql",
    "dashboard/geography_performance.sql",
]


def run_sql(cursor, filename):
    sql = (SQL_DIR / filename).read_text()
    cursor.execute(sql)


def main():
    with connect() as conn:
        with conn.cursor() as cursor:
            print("Building dashboard layer")

            for filename in DASHBOARD_FILES:
                print(f"  {filename}")
                run_sql(cursor, filename)

    print("\nDashboard layer rebuild complete.")


if __name__ == "__main__":
    main()
