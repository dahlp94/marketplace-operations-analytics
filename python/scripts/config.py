"""Shared project configuration."""

import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv


ROOT = Path(__file__).resolve().parents[2]

load_dotenv(ROOT / ".env")


RAW_DIR = ROOT / "data" / "raw"
SQL_DIR = ROOT / "sql"
OUTPUT_DIR = ROOT / "outputs" / "source_audit"
QUALITY_OUTPUT_DIR = ROOT / "outputs" / "quality_investigation"
MODEL_OUTPUT_DIR = ROOT / "outputs" / "model_validation"


SOURCE_FILES = {
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "customers": "olist_customers_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "products": "olist_products_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "product_category_translation": "product_category_name_translation.csv",
}


def connect():
    return psycopg2.connect(
        host=os.getenv("PGHOST", "127.0.0.1"),
        port=os.getenv("PGPORT", "55432"),
        user=os.getenv("PGUSER", "marketplace"),
        dbname=os.getenv("PGDATABASE", "marketplace_ops"),
        password=os.getenv("PGPASSWORD") or None,
    )