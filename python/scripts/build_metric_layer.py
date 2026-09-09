#!/usr/bin/env python3
"""Build the reusable metrics layer from certified analytics tables."""

from python.scripts.config import SQL_DIR, connect


METRIC_FILES = [
    "metrics/00_create_schema.sql",
    "metrics/10_kpi_orders.sql",
    "metrics/11_kpi_customers.sql",
    "metrics/12_kpi_seller_orders.sql",
    "metrics/13_kpi_sellers.sql",
    "metrics/14_kpi_marketplace.sql",
    "metrics/20_constraints.sql",
]


def run_sql(cursor, filename):
    sql = (SQL_DIR / filename).read_text()
    cursor.execute(sql)


def main():
    with connect() as conn:
        with conn.cursor() as cursor:
            print("Building metric layer")

            for filename in METRIC_FILES:
                print(f"  {filename}")
                run_sql(cursor, filename)

    print("\nMetric layer rebuild complete.")


if __name__ == "__main__":
    main()
