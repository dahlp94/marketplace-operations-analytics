#!/usr/bin/env python3
"""Rebuild the staging and analytics layers from raw data."""

from python.scripts.config import SQL_DIR, connect


STAGING_FILES = [
    "staging/00_create_schema.sql",
    "staging/01_stg_geolocation_zip.sql",
    "staging/02_stg_orders.sql",
    "staging/03_stg_order_items.sql",
    "staging/04_stg_order_payments.sql",
    "staging/05_stg_order_reviews.sql",
    "staging/06_stg_products.sql",
]

ANALYTICS_FILES = [
    "analytics/00_create_schema.sql",
    "analytics/01_dim_date.sql",
    "analytics/02_dim_geography.sql",
    "analytics/03_dim_customer.sql",
    "analytics/04_dim_seller.sql",
    "analytics/05_dim_product.sql",
    "analytics/10_fact_orders.sql",
    "analytics/11_fact_order_items.sql",
    "analytics/12_fact_payments.sql",
    "analytics/13_fact_reviews.sql",
    "analytics/20_constraints.sql",
]


def run_sql(cursor, filename):
    sql = (SQL_DIR / filename).read_text()
    cursor.execute(sql)


def main():
    with connect() as conn:
        with conn.cursor() as cursor:
            print("Building staging tables")

            for filename in STAGING_FILES:
                print(f"  {filename}")
                run_sql(cursor, filename)

            print("\nBuilding analytics tables")

            for filename in ANALYTICS_FILES:
                print(f"  {filename}")
                run_sql(cursor, filename)

    print("\nAnalytical model rebuild complete.")


if __name__ == "__main__":
    main()
