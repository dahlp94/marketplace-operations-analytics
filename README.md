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

The current repository contains the data foundation, quality controls, analytical model, metric contracts, reusable KPI layer, certified KPI outputs, a fulfillment root-cause analysis, seller concentration work, a customer-experience analysis linking delivery performance to review outcomes, and statistical validation of those findings.


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

### Fulfillment performance

Inside the comparable window (February 2017–August 2018; 95,453 eligible orders), the marketplace late rate was **6.82%** (6,509 late orders; R$982,503 late GMV). That average hides two different deterioration patterns:

* **November 2017 and February–March 2018** — late rates reached **12.4%**, **14.1%**, and **18.96%**. These months are associated with longer **carrier transit** at both the mean and the median. Rio de Janeiro customer destinations show the sharpest concentration (about **34%** late in February and March 2018, versus a **3.5%** early-2017 marketplace baseline).
* **August 2018** — the late rate rose to **6.19%** while fulfillment got faster. Median promised windows fell from **28 days in June to 14 days in August**. São Paulo accounts for **285 of 393** August late orders, consistent with tighter promises rather than slower handling or transit.

Late orders in the comparable window have a median transit of **26.2 days** versus **6.9 days** for orders that were not late. Median handling is secondarily elevated (**3.1 vs 1.8 days**). Median promised windows are almost the same (**23 vs 24 days**). Extreme delays exist and are transit-dominated, but excluding the top 1% of transit times does not remove the spike months.

These are associations, not proven causes. Details are in [`docs/root_cause_analysis.md`](docs/root_cause_analysis.md).

### Seller concentration

Late seller-orders are moderately concentrated: **98 sellers account for 50%** of the 6,547 certified late seller-orders, and **398 account for 80%**. The largest contributor has **172 late / 1,772 eligible (9.71%)**, or **2.63%** of marketplace late units.

Rate and contribution are not the same thing. Relative to the marketplace seller-order late rate of **6,547 / 97,811 = 6.69%**, the largest contributor has about **53 excess late seller-orders**, while another high-volume seller with 96 late units sits **26 below** expected. A candidate watchlist of **25 sellers** is flagged from excess late, high-rate/high-volume, or recent July–August change. It is an investigation set, not a remediation ranking.

Details are in [`docs/seller_concentration.md`](docs/seller_concentration.md).

### Customer experience

Delivery performance is strongly associated with review outcomes, but missing reviews are not random.

Among delivery-performance-eligible reviewed orders, **62.34%** of late orders are negative (3,932 / 6,307; average score **2.27**) versus **9.11%** of early orders (7,945 / 87,203; average score **4.30**). The gap is graded by delay: **31.97%** negative at 1–3 days late and **80.29%** at 8–14 days late. Unreviewed delivered orders are about twice as late as reviewed ones (**13.38%** versus **6.65%**), and repeat-order coverage drops to **81.38%**.

The association remains large inside GMV bands and after excluding extreme delays. It is not a causal estimate. Details are in [`docs/customer_experience_analysis.md`](docs/customer_experience_analysis.md).

### Statistical validation

The descriptive gaps remain large after uncertainty and adjustment.

The late-versus-early negative-review difference is **53.23 percentage points** (95% CI **52.02–54.44**; 6,307 late vs 87,203 early reviewed orders). A 1–3 day delay still has a **22.86 point** gap. Order-level and seller-clustered bootstraps (seed 0, 2,000 resamples) give nearly the same interval.

November 2017 and February–March 2018 remain far above the early-2017 baseline (**+8.89 pp** and **+13.11 pp**). August 2018 is only **+2.67 pp**, consistent with a different failure mode. The 25-seller watchlist has a pooled late rate of **9.17%** versus **6.23%** among other sellers; some recent-deterioration sellers have lifetime intervals that overlap the marketplace rate, so the list stays an investigation queue.

After adjusting for order value, purchase sequence, customer state, and multi-seller structure, late delivery has an odds ratio of **16.92** (15.98–17.91) for a negative review versus early delivery. Predicted probabilities match the descriptive rates. Excluding extreme delays does not remove the association.

These are adjusted associations, not causal effects. Details are in [`docs/statistical_validation.md`](docs/statistical_validation.md).


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
* **Python** — reproducible data download, loading, audit orchestration, and statistical / visual analysis
* **pandas / matplotlib / statsmodels / scipy** — extracts, confidence intervals, bootstrap, logistic regression, and charts
* **pytest** — executable data-quality, metric-contract, and analysis checks
* **KaggleHub** — reproducible dataset download
* **Git / GitHub** — version control and project documentation


## Repository structure

```text
data/                  # raw-data instructions; CSV extracts are gitignored
sql/raw/               # raw PostgreSQL schema and table definitions
sql/quality/           # source profiling and data-quality investigation
sql/staging/           # treated copies of raw tables
sql/analytics/         # dimensions, facts, constraints, and model validation
sql/certification/     # independent raw-vs-analytics foundation certification
sql/metrics/           # metric definitions, validation, and KPI SQL
sql/analysis/          # trends, rankings, contribution, segments, fulfillment, seller, CX, and inference extracts
sql/kpi_certification/ # independent KPI and analysis-layer certification
python/scripts/        # download, load, audit, model, and analysis runners
python/notebooks/      # fulfillment, seller, customer-experience, and statistical-validation narratives
docs/                  # source, quality, analytical-model, metric, and findings documentation
tests/                 # source-structure, quality, model, and metric-contract checks
scripts/               # local PostgreSQL setup
outputs/               # generated audit, validation, metric, and analysis results
outputs/figures/       # fulfillment, seller, customer-experience, and statistical-validation charts
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
schemas:  raw, stg, analytics, metrics, analysis
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

### 9. Certify the foundation

```bash
python -m python.scripts.run_certification
```

This independently reconciles raw versus analytics entity counts, status populations, monetary totals, grains, treatments, and sample-order lineage.

Generated outputs are saved under:

```text
outputs/certification/
```

### 10. Run automated checks

```bash
pytest -q
```

Current test suite:

```text
108 passed
```

### 11. Validate metric definitions

```bash
python -m python.scripts.run_metric_contract_validation
pytest tests/test_metric_contracts.py -q
```

This recalculates analytical populations, delivery classification, seller attribution, review, and repeat-customer definitions from the certified model. It does not build the reusable KPI layer.

### 12. Build and validate the metric layer

```bash
python -m python.scripts.build_metric_layer
python -m python.scripts.run_metric_layer_validation
pytest tests/test_metric_layer.py -q
```

This creates reusable `metrics.*` tables from the certified analytical model and independently spot-checks them against `analytics.*`.

### 13. Build and validate the analysis layer

```bash
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_analysis_validation
pytest tests/test_analysis_layer.py tests/test_fulfillment_root_cause.py tests/test_seller_concentration.py tests/test_customer_experience.py tests/test_statistical_validation.py -q
```

This creates reusable `analysis.*` trend, ranking, contribution, segmentation, fulfillment, seller, and customer-experience tables from the certified KPI layer.

### 14. Certify the KPI and analysis layers

```bash
python -m python.scripts.run_kpi_certification
pytest tests/test_kpi_certification.py -q
```

This independently recalculates marketplace KPIs, seller contribution, category and geography grains, rolling windows, rankings, repeat-customer sequences, and review denominators from certified `analytics.*` tables. It also records representative query plans.

Generated outputs are saved under:

```text
outputs/kpi_certification/
```

### 15. Run the fulfillment root-cause analysis

```bash
python -m python.scripts.run_fulfillment_root_cause
pytest tests/test_fulfillment_root_cause.py -q
```

This reuses certified handling, transit, promise, and late-delivery fields. It writes monthly decomposition extracts, segment comparisons, outlier-sensitivity tables, and trend charts.

Generated outputs are saved under:

```text
outputs/analysis/fulfillment_*.csv
outputs/figures/
```

The narrative notebook is `python/notebooks/fulfillment_root_cause_analysis.ipynb`.

### 16. Run the seller concentration analysis

```bash
python -m python.scripts.run_seller_concentration
pytest tests/test_seller_concentration.py -q
```

This reuses certified seller-order late rate, contribution, and seller-item GMV. It writes excess-late calculations, volume-threshold sensitivity, a candidate watchlist, and concentration charts.

Generated outputs are saved under:

```text
outputs/analysis/seller_*.csv
outputs/figures/seller_*.png
```

The narrative notebook is `python/notebooks/seller_concentration_analysis.ipynb`.

### 17. Run the customer-experience analysis

```bash
python -m python.scripts.run_customer_experience
pytest tests/test_customer_experience.py -q
```

This reuses certified delivery class, delay days, review scores, and negative-review flags. It writes coverage, delivery/review cross-tabs, delay-band rates, segment splits, and CX charts.

Generated outputs are saved under:

```text
outputs/analysis/review_*.csv
outputs/analysis/delivery_review_*.csv
outputs/analysis/delay_band_reviews.csv
outputs/figures/cx_*.png
```

The narrative notebook is `python/notebooks/customer_experience_analysis.ipynb`.

### 18. Run statistical validation

```bash
python -m python.scripts.run_statistical_validation
pytest tests/test_statistical_validation.py -q
```

This reuses certified late-delivery, review, and seller-order counts. It writes Wilson intervals, group comparisons, bootstrap estimates, a logistic review-outcome model, diagnostics, and sensitivity checks.

Generated outputs are saved under:

```text
outputs/analysis/review_effect_estimates.csv
outputs/analysis/group_comparisons.csv
outputs/analysis/bootstrap_estimates.csv
outputs/analysis/review_outcome_model.csv
outputs/figures/stat_*.png
```

The narrative notebook is `python/notebooks/statistical_validation.ipynb`.


## Documentation

| Document                                                     | Purpose                                                                      |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| [`docs/source_inventory.md`](docs/source_inventory.md)       | Raw tables, grains, candidate keys, and source observations                  |
| [`docs/relationship_audit.md`](docs/relationship_audit.md)   | Cardinality, customer identity, FK coverage, and join safety                 |
| [`docs/er_diagram.md`](docs/er_diagram.md)                   | Source-level relational model                                                |
| [`docs/data_quality_report.md`](docs/data_quality_report.md) | Quality findings, treatment rules, metric eligibility, and known limitations |
| [`docs/data_model.md`](docs/data_model.md)                   | Analytical table grains, treatments, and geography resolution                |
| [`docs/analytical_er_diagram.md`](docs/analytical_er_diagram.md) | Analytical facts, dimensions, keys, and cardinality                      |
| [`docs/foundation_certification.md`](docs/foundation_certification.md) | Independent reconciliation and certification of the analytical foundation |
| [`docs/metric_dictionary.md`](docs/metric_dictionary.md) | Metric definitions, populations, grains, and attribution rules |
| [`docs/metric_layer.md`](docs/metric_layer.md) | Reusable KPI table grains, join safety, and rebuild instructions |
| [`docs/analysis_layer.md`](docs/analysis_layer.md) | Trends, rolling windows, rankings, contribution, segments, fulfillment, seller, customer-experience, and inference extracts |
| [`docs/kpi_certification.md`](docs/kpi_certification.md) | Independent KPI reconciliation, SQL QA, query-plan review, and certification decision |
| [`docs/root_cause_analysis.md`](docs/root_cause_analysis.md) | Fulfillment decomposition, delivery trends, and segment findings |
| [`docs/seller_concentration.md`](docs/seller_concentration.md) | Seller contribution, excess late orders, and candidate watchlist |
| [`docs/customer_experience_analysis.md`](docs/customer_experience_analysis.md) | Delivery performance associated with review coverage, scores, and negative reviews |
| [`docs/statistical_validation.md`](docs/statistical_validation.md) | Confidence intervals, group comparisons, bootstrap, review-outcome model, and sensitivity |


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
* grain-safe order, item, payment, and review facts;
* analytical-model tests and validation SQL;
* foundation reconciliation and certification;
* Metric definitions and analytical population rules;
* reusable fulfillment, seller, CX, repeat-customer, and commercial KPI tables;
* advanced SQL trends, rankings, contribution, cohort, and segmentation tables;
* independent KPI reconciliation, structural SQL QA, and query-plan review;
* fulfillment root-cause decomposition of late delivery into seller handling, carrier transit, and promise performance;
* seller concentration, excess-late comparison, and a candidate operational watchlist;
* customer-experience analysis of how delivery performance is associated with review outcomes;
* statistical validation of the main late-delivery and review differences, including intervals, bootstrap checks, and an adjusted review-outcome model.

The metric and analysis layers are certified. Final intervention recommendations come next and must reuse these certified contracts.

Raw-source anomalies will not be reinterpreted independently in later analysis; the analytical layer uses the treatment rules documented in [`docs/data_quality_report.md`](docs/data_quality_report.md) and [`docs/data_model.md`](docs/data_model.md).
