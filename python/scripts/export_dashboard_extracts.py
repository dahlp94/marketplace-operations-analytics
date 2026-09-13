#!/usr/bin/env python3
"""Export dashboard views to CSV extracts for Tableau."""

from decimal import Decimal

import pandas as pd

from python.scripts.config import DASHBOARD_OUTPUT_DIR, connect


EXPORTS = {
    "executive_overview": "SELECT * FROM dashboard.executive_overview ORDER BY reporting_scope",
    "fulfillment_trends": "SELECT * FROM dashboard.fulfillment_trends ORDER BY purchase_month",
    "fulfillment_components": """
        SELECT * FROM dashboard.fulfillment_components
        ORDER BY analysis_period, delivery_class
    """,
    "marketplace_rolling": "SELECT * FROM dashboard.marketplace_rolling ORDER BY purchase_date",
    "delivery_review": "SELECT * FROM dashboard.delivery_review ORDER BY delivery_class",
    "delay_band_reviews": "SELECT * FROM dashboard.delay_band_reviews ORDER BY delay_band_sort",
    "seller_performance": """
        SELECT * FROM dashboard.seller_performance
        ORDER BY late_seller_orders DESC NULLS LAST, seller_id
    """,
    "seller_month": """
        SELECT * FROM dashboard.seller_month
        ORDER BY seller_id, purchase_month
    """,
    "category_performance": """
        SELECT * FROM dashboard.category_performance
        ORDER BY reporting_scope, late_units DESC NULLS LAST, product_category
    """,
    "geography_performance": """
        SELECT * FROM dashboard.geography_performance
        ORDER BY reporting_scope, late_orders DESC NULLS LAST, customer_state
    """,
    "geography_month": """
        SELECT * FROM dashboard.geography_month
        ORDER BY customer_state, purchase_month
    """,
}


def read_sql(conn, sql):
    with conn.cursor() as cursor:
        cursor.execute(sql)
        frame = pd.DataFrame(cursor.fetchall(), columns=[c[0] for c in cursor.description])

    for column in frame.columns:
        if frame[column].map(lambda value: isinstance(value, Decimal)).any():
            frame[column] = pd.to_numeric(frame[column], errors="coerce")
    return frame


def main():
    DASHBOARD_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with connect() as conn:
        for name, sql in EXPORTS.items():
            path = DASHBOARD_OUTPUT_DIR / f"{name}.csv"
            read_sql(conn, sql).to_csv(path, index=False)
            print(f"Wrote {path}")


if __name__ == "__main__":
    main()
