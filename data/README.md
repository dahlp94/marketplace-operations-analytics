# Data

This project uses the **Brazilian E-Commerce Public Dataset by Olist** from Kaggle.

The raw CSV files are stored in:

```text
data/raw/
```

Raw files are treated as **immutable source data**. Do not manually edit them to fix missing values, duplicates, inconsistent categories, timestamps, or other quality issues. Data-quality investigation and treatment happen in SQL after the raw load.


## Source

**Dataset:** Brazilian E-Commerce Public Dataset by Olist
**Kaggle dataset:** `olistbr/brazilian-ecommerce`

The dataset contains relational marketplace data covering:

* orders
* order items
* payments
* reviews
* customers
* sellers
* products
* geolocation
* product-category translation

The translation file is included in the official Kaggle dataset and is used to map Portuguese product categories to English labels.


## Download

The project uses `kagglehub` to download the dataset directly from Kaggle.

Add your Kaggle API token to `.env`:

```text
KAGGLE_API_TOKEN=your_token_here
```

Then run from the project root:

```bash
python -m python.scripts.download_raw
```

The script downloads the Olist dataset and copies the required CSV files into:

```text
data/raw/
```

You can also download the dataset manually from Kaggle and place the required files in `data/raw/`.


## Expected files

| Source file                             | Raw PostgreSQL table               |      Rows |
| --------------------------------------- | ---------------------------------- | --------: |
| `olist_orders_dataset.csv`              | `raw.orders`                       |    99,441 |
| `olist_order_items_dataset.csv`         | `raw.order_items`                  |   112,650 |
| `olist_order_payments_dataset.csv`      | `raw.order_payments`               |   103,886 |
| `olist_order_reviews_dataset.csv`       | `raw.order_reviews`                |    99,224 |
| `olist_customers_dataset.csv`           | `raw.customers`                    |    99,441 |
| `olist_sellers_dataset.csv`             | `raw.sellers`                      |     3,095 |
| `olist_products_dataset.csv`            | `raw.products`                     |    32,951 |
| `olist_geolocation_dataset.csv`         | `raw.geolocation`                  | 1,000,163 |
| `product_category_name_translation.csv` | `raw.product_category_translation` |        71 |

These counts correspond to the Olist extract used by this project.


## Load into PostgreSQL

After the files are available, load them into the PostgreSQL `raw` schema:

```bash
python -m python.scripts.load_raw
```

The loader:

1. creates the raw schema and source tables;
2. loads each CSV using PostgreSQL `COPY`;
3. preserves the source table grain without cleaning or deduplication;
4. counts logical CSV records;
5. compares each CSV count with the corresponding PostgreSQL table count;
6. fails if the counts do not match.

A successful load ends with:

```text
Raw load complete. All row counts match.
```


## Why logical CSV row counts matter

The review dataset contains free-text comments that can include embedded newline characters.

Because of this, a command such as:

```bash
wc -l data/raw/olist_order_reviews_dataset.csv
```

does not necessarily represent the number of CSV records.

The project counts records using Python's CSV parser instead of counting physical lines.


## Raw-data policy

The `raw` schema is intended to represent the source extract as faithfully as practical.

The raw layer does **not**:

* remove duplicates;
* repair timestamps;
* standardize categories;
* resolve review anomalies;
* collapse geolocation records;
* reconcile payment and item totals;
* exclude unusual orders.

Those issues are investigated separately so that every treatment remains explicit and auditable.


## Source audit

After loading the raw data, run:

```bash
python -m python.scripts.run_source_audit
```

The source audit checks:

* row counts;
* candidate-key uniqueness;
* important null patterns;
* child-to-parent coverage;
* parent-child cardinality;
* customer identity;
* join fan-out risk;
* representative order lineage.

Generated audit outputs are written to:

```text
outputs/source_audit/
```

After the source audit, run the Stage 2 quality investigation:

```bash
python -m python.scripts.run_quality_investigation
```

Generated quality outputs are written to:

```text
outputs/quality_investigation/
```

After the quality investigation, build and certify the analytical model from `raw`:

```bash
python -m python.scripts.build_analytical_model
python -m python.scripts.run_model_validation
python -m python.scripts.run_foundation_certification
```

Automated structural, quality, model, and certification tests can also be run with:

```bash
pytest -q
```


## Git

Raw CSV files are excluded from version control.

The repository contains:

* download instructions;
* loading code;
* SQL definitions;
* validation queries;
* tests;
* documentation;

rather than committing the source dataset itself.

This keeps the repository small while preserving a reproducible path from the Kaggle dataset to the PostgreSQL raw layer.
