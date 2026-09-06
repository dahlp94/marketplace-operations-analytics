# Marketplace Operations & Customer Experience Intelligence

An end-to-end marketplace analytics project using the Olist Brazilian E-Commerce dataset to investigate how fulfillment, seller performance, product mix, geography, and customer experience interact.

## Business problem

Marketplace operations teams need to know:

> **Which operational problems are driving poor customer experience, and where should Operations intervene first?**

The project is being built to answer questions such as:

* Where is delivery performance deteriorating?
* Which sellers, categories, and regions contribute most to late deliveries?
* How strongly is delivery performance associated with customer reviews?
* Is poor delivery driven by seller handling time, carrier transit time, or unrealistic delivery promises?
* Which operational problems affect the largest share of orders and marketplace value?
* Which sellers or operational segments should be prioritized for intervention?

The current repository contains the **data foundation, quality controls, and analytical model** required to answer those questions reliably. KPI development and root-cause analysis come next.


## Why the data foundation matters

The Olist dataset is relational, and several seemingly simple joins can produce incorrect results.

For example:

* orders can contain multiple items;
* orders can use multiple payment records;
* one order can involve multiple sellers;
* `customer_id` identifies an order-scoped customer record, while `customer_unique_id` identifies the underlying buyer;
* reviews are not strictly one-per-order;
* geolocation contains many rows per ZIP prefix;
* directly joining order items to payments multiplies monetary values.

The project explicitly audits these relationships before building business metrics.


## Key findings so far

### Source structure

* **99,441 orders**
* **112,650 order items**
* **103,886 payment records**
* **99,224 review records**
* **96,096 unique buyers**
* **3,095 sellers**
* **32,951 products**

Important structural findings:

* 9,803 orders contain multiple items.
* 2,961 orders contain multiple payment records.
* 1,278 orders involve multiple sellers.
* 547 orders contain multiple review rows.
* `review_id` is not unique by itself.
* geolocation contains 1,000,163 rows but only 19,015 ZIP prefixes.

A naive join between items and payments can materially overstate both merchandise and payment totals, so financial measures are calculated at their native grains before aggregation.

### Data quality

The quality investigation identified several issues that require explicit treatment rather than silent deletion:

* 8 delivered orders are missing a customer-delivery timestamp.
* 1,359 orders have carrier handoff recorded before approval.
* 23 delivered orders have customer delivery recorded before carrier handoff.
* 610 products have no source category.
* 13 products belong to categories missing from the English translation table.
* 278 customer records and 7 sellers have ZIP prefixes absent from the geolocation source.
* 303 of 98,665 comparable orders differ by more than R$0.01 between item-side value and payment value.
* the beginning and end of the extract contain sparse historical coverage unsuitable for direct month-over-month comparison.

Rather than creating one global “clean data” filter, downstream metrics use **metric-specific eligibility rules**.

For example:

| Metric                   | Usable delivered orders |
| ------------------------ | ----------------------: |
| On-time delivery         |                  96,470 |
| Purchase → delivery time |                  96,470 |
| Seller handling time     |                  95,112 |
| Carrier transit time     |                  96,281 |

This preserves usable information instead of unnecessarily discarding entire orders.


## Data-quality principles

The project follows a few simple rules:

* Raw source files are immutable.
* Raw PostgreSQL tables are not manually repaired.
* Missing or inconsistent records are retained whenever possible.
* Quality issues are flagged rather than silently removed.
* Exclusions are defined at the **metric level**.
* Item and payment measures remain separate until they are safely aggregated to a common grain.
* Missing product categories are preserved rather than dropped.
* Raw geolocation is aggregated before geographic enrichment.
* Historical boundary periods are excluded only from analyses that require comparable monthly coverage.

Detailed findings and treatment rules are documented in [`docs/data_quality_report.md`](docs/data_quality_report.md).


## Tech stack

* **SQL / PostgreSQL** — relational modeling, quality investigation, reconciliation, and analytical queries
* **Python** — reproducible data download, loading, and audit orchestration
* **pytest** — executable data-quality and source-structure checks
* **KaggleHub** — reproducible dataset download
* **Git / GitHub** — version control and project documentation


## Repository structure

```text
data/                  # raw-data instructions; CSV extracts are gitignored
sql/raw/               # raw PostgreSQL schema and table definitions
sql/quality/           # source profiling and data-quality investigation
sql/staging/           # treated copies of raw tables
sql/analytics/         # dimensions, facts, constraints, and model validation
python/scripts/        # download, load, audit, and model runners
docs/                  # source, quality, and analytical-model documentation
tests/                 # source-structure, quality, and model checks
scripts/               # local PostgreSQL setup
outputs/               # generated audit and validation results
```


## Data source

The project uses the **Brazilian E-Commerce Public Dataset by Olist**.

Kaggle dataset:

```text
olistbr/brazilian-ecommerce
```

The source contains relational data for:

* orders
* order items
* payments
* reviews
* customers
* sellers
* products
* geolocation
* product-category translations

Raw CSV files are downloaded locally and are not committed to Git.

See [`data/README.md`](data/README.md) for details.


## Reproduce the project foundation

### 1. Install dependencies

```bash
python -m pip install -r requirements.txt
```

### 2. Start the local PostgreSQL database

```bash
./scripts/setup_local_postgres.sh
```

Default local configuration:

```text
host:     127.0.0.1
port:     55432
user:     marketplace
database: marketplace_ops
schemas:  raw, stg, analytics
```

Configuration can be overridden through `.env`.

### 3. Download the Olist data

```bash
python -m python.scripts.download_raw
```

### 4. Load the raw tables

```bash
python -m python.scripts.load_raw
```

The loader compares logical CSV record counts with PostgreSQL table counts and fails if they do not match.

### 5. Run the source audit

```bash
python -m python.scripts.run_source_audit
```

This evaluates:

* row counts
* candidate-key uniqueness
* null patterns
* child-to-parent coverage
* cardinality
* customer identity
* join fan-out
* representative order lineage

### 6. Run the data-quality investigation

```bash
python -m python.scripts.run_quality_investigation
```

This investigates:

* review anomalies
* missingness
* timestamp validity
* order-status consistency
* product-category coverage
* geography quality
* monetary reconciliation
* historical coverage
* downstream treatment impact

### 7. Build the analytical model

```bash
python -m python.scripts.build_analytical_model
```

This rebuilds schemas `stg` and `analytics` from `raw` without modifying raw tables.

### 8. Validate the analytical model

```bash
python -m python.scripts.run_model_validation
```

This checks uniqueness, referential integrity, geography join stability, fan-out protection, sample-order lineage, and treatment coverage.

Generated outputs are saved under:

```text
outputs/model_validation/
```

### 9. Run automated checks

```bash
pytest -q
```

Current test suite:

```text
45 passed
```


## Documentation

| Document                                                     | Purpose                                                                      |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| [`docs/source_inventory.md`](docs/source_inventory.md)       | Raw tables, grains, candidate keys, and source observations                  |
| [`docs/relationship_audit.md`](docs/relationship_audit.md)   | Cardinality, customer identity, FK coverage, and join safety                 |
| [`docs/er_diagram.md`](docs/er_diagram.md)                   | Source-level relational model                                                |
| [`docs/data_quality_report.md`](docs/data_quality_report.md) | Quality findings, treatment rules, metric eligibility, and known limitations |
| [`docs/data_model.md`](docs/data_model.md)                   | Analytical table grains, treatments, geography, and seller-SLA generation    |
| [`docs/analytical_er_diagram.md`](docs/analytical_er_diagram.md) | Analytical facts, dimensions, keys, and cardinality                      |


## Current scope

Completed:

* reproducible raw-data download and PostgreSQL load;
* source inventory and grain validation;
* relationship and join-safety audit;
* customer identity validation;
* data-quality investigation;
* monetary reconciliation;
* historical coverage assessment;
* documented downstream treatment rules;
* staging transformations and quality flags;
* geography lookup and core dimensions;
* synthetic seller-SLA dimension;
* grain-safe order, item, payment, and review facts;
* analytical-model tests and validation SQL.

Next work will certify the model and then build the KPI layer needed to investigate delivery performance, seller operations, customer experience, and intervention priorities.

Raw-source anomalies will not be reinterpreted independently in later analysis; the analytical layer uses the treatment rules documented in [`docs/data_quality_report.md`](docs/data_quality_report.md) and [`docs/data_model.md`](docs/data_model.md).
