# Data Quality Report

This report summarizes the data-quality investigation performed on the raw Olist tables loaded into PostgreSQL schema `raw`.

The purpose is to identify source-data issues that could distort marketplace operations and customer-experience metrics, define explicit treatment rules, and quantify where those rules affect downstream analysis.

Raw tables remain unchanged. Cleaning, flags, metric eligibility, and standardization are applied only in downstream analytical layers.

Reproducible evidence comes from:

```text
sql/quality/08_review_anomalies.sql
sql/quality/09_missingness.sql
sql/quality/10_timestamp_validity.sql
sql/quality/11_status_consistency.sql
sql/quality/12_product_category.sql
sql/quality/13_geography.sql
sql/quality/14_monetary_reconciliation.sql
sql/quality/15_time_coverage.sql
sql/quality/16_treatment_impact.sql
```

Run the investigation with:

```bash
python -m python.scripts.run_quality_investigation
```

Generated outputs are saved under:

```text
outputs/quality_investigation/
```

The source inventory, relationship audit, and source ER diagram remain the reference for table grain, candidate keys, cardinality, customer identity, and join safety.


## Executive summary

The raw extract is broadly usable, but several issues require explicit treatment before KPI construction.

| Issue | Evidence | Treatment |
|---|---|---|
| Reused review IDs | 789 `review_id` values appear on 1,603 rows; reused IDs always carry identical review payloads | keep raw rows; flag reused IDs; exclude ambiguous reused-ID rows from order-level CX aggregation |
| Multiple reviews per order | 547 orders have multiple review rows; 202 have differing scores | aggregate valid review rows to one order-level score; preserve review count |
| Missing delivered-order lifecycle timestamps | 23 delivered orders are missing at least one approval, carrier, or customer-delivery timestamp | keep orders; use metric-specific eligibility instead of deleting rows |
| Invalid seller-handling sequence | 1,359 orders have carrier handoff before approval | exclude from approval-to-carrier handling-time metrics |
| Invalid carrier sequence | 23 delivered orders have customer delivery before carrier handoff | exclude from carrier-to-customer transit metrics |
| Status/timestamp conflicts | 6 canceled orders have a customer-delivery timestamp | retain source status; flag the conflict; do not count as delivered |
| Missing product category | 610 products | retain; label category as `unknown` downstream |
| Untranslated category | 13 products across 2 category names | retain the Portuguese source category as fallback |
| Raw geolocation is not a ZIP dimension | 17,972 of 19,015 ZIP prefixes have multiple rows | aggregate geolocation before joining to customers or sellers |
| Geography coverage gaps | 278 customer rows and 7 seller rows have ZIP prefixes absent from geolocation | retain source city/state; leave coordinates null |
| Item/payment differences | 303 of 98,665 comparable orders differ by more than R$0.01 | flag differences; never force item and payment totals to agree |
| Sparse boundary periods | 2016 is sparse; September–October 2018 contain only 20 orders and no delivered orders | restrict comparable monthly trend reporting to the stable coverage period |

The investigation changes **metric eligibility**, not source-row existence.


## 1. Review anomalies

### Reused `review_id`

The review source contains:

- 789 reused `review_id` values
- 1,603 review rows carrying those IDs
- 1,412 distinct orders affected
- maximum of 3 rows for one reused ID

For every reused `review_id`, the score, comment fields, creation date, and answer timestamp are identical across occurrences.

This indicates that `review_id` alone cannot safely represent a unique customer opinion in this extract.

### Treatment

- Keep all raw review rows unchanged.
- Add a `review_id_reused` quality flag downstream.
- Do not treat reused IDs as separate independent customer opinions.
- Exclude reused-ID rows from the order-level CX score used for operational analysis.
- Keep `(review_id, order_id)` as the observed source-row key.

### Multiple reviews per order

There are:

- 547 orders with multiple review rows
- 345 where all review scores agree
- 202 where review scores differ
- maximum of 3 review rows on one order

Multiple rows should not cause an order to receive extra weight in CX metrics.

### Treatment

For order-level CX analysis:

1. remove rows flagged as reused review IDs from the score aggregation;
2. aggregate remaining review scores to one value per order using the mean;
3. retain `n_reviews` as a diagnostic field.

Orders without a valid review remain missing from review-based metrics rather than being assigned a satisfaction value.

### Review timing

The source also contains:

- 74 reviews with `review_creation_date` before purchase
- 8,319 review rows on delivered orders where review creation precedes the recorded customer-delivery timestamp
- 0 review rows where answer timestamp precedes creation timestamp

The extract therefore does not support treating `review_creation_date - delivery_timestamp` as a reliable customer-response clock.

### Treatment

- Do not exclude a review solely because its creation date precedes the recorded delivery timestamp.
- Do not use review creation minus delivery as a time-to-review KPI.
- Treat review timing anomalies as a documented source limitation.


## 2. Missingness and lifecycle validity

### Order timestamps

Missing timestamps are strongly related to order status and are often structurally expected for incomplete orders.

Among 96,478 delivered orders:

| Field | Missing |
|---|---:|
| `order_approved_at` | 14 |
| `order_delivered_carrier_date` | 2 |
| `order_delivered_customer_date` | 8 |
| Any of the three | 23 |

These rows should not be deleted from the order population simply because one lifecycle timestamp is unusable.

### Timestamp sequence checks

| Check | Violations |
|---|---:|
| approval before purchase | 0 |
| carrier before approval | 1,359 |
| carrier before purchase | 166 |
| customer delivery before carrier | 23 |
| customer delivery before purchase | 0 |
| estimated delivery before purchase date | 0 |
| shipping limit before purchase | 0 |

The main issue is that carrier handoff does not always follow approval in the source. That makes approval-to-carrier handling time a metric with stricter eligibility than general delivery metrics.

### Metric-specific eligibility

Delivered-order population: **96,478**.

| Metric | Eligibility rule | Usable orders |
|---|---|---:|
| On-time delivery | customer-delivery timestamp exists | 96,470 |
| Purchase → delivery | customer delivery exists and is not before purchase | 96,470 |
| Seller handling | approval and carrier timestamps exist; approval ≥ purchase; carrier ≥ approval | 95,112 |
| Carrier transit | carrier and customer-delivery timestamps exist; carrier ≥ purchase; customer delivery ≥ carrier | 96,281 |

### Treatment

Do not create one global “clean order” filter.

Instead, each KPI uses the timestamps required for that KPI:

- on-time delivery uses delivered orders with a customer-delivery timestamp;
- purchase-to-delivery uses a valid purchase/customer sequence;
- seller handling uses only valid approval-to-carrier sequences;
- carrier transit uses only valid carrier-to-customer sequences.

Orders failing one metric's eligibility can still be valid for other metrics.


## 3. Order-status consistency

Observed status conflicts include:

- 8 delivered orders without customer-delivery timestamps
- 2 delivered orders without carrier timestamps
- 6 canceled orders with customer-delivery timestamps
- 1 delivered order without payment rows
- 775 orders without item rows, concentrated in incomplete statuses

Orders without item rows by status:

| Status | Orders without items |
|---|---:|
| unavailable | 603 |
| canceled | 164 |
| created | 5 |
| invoiced | 2 |
| shipped | 1 |
| delivered | 0 |

The missing-item pattern is therefore largely consistent with orders that never reached normal fulfillment.

### Treatment

- Preserve the source `order_status`.
- Do not reinterpret canceled orders as delivered because a delivery timestamp exists.
- Flag status/timestamp conflicts where useful.
- Keep orders without items in order-level operational populations.
- Item-based merchandise metrics naturally include only orders with item rows.
- Keep the one delivered order without payment rows in order/item analysis but exclude it from collected-payment measures.


## 4. Product completeness

### Missing category

Of 32,951 products:

- 610 have a null `product_category_name`
- 2 have missing weight
- 2 have at least one missing physical dimension

The 610 uncategorized products appear on:

- 1,603 item rows
- 1,451 orders
- R$207,705.09 of item-side value

Dropping these products would remove real marketplace activity.

### Missing translation

There are 13 categorized products whose Portuguese category has no translation row.

The two unmatched categories are:

| Source category | Products | Item rows | Orders | Item-side value |
|---|---:|---:|---:|---:|
| `portateis_cozinha_e_preparadores_de_alimentos` | 10 | 15 | 14 | R$4,278.29 |
| `pc_gamer` | 3 | 9 | 8 | R$1,679.52 |

Combined missing/untranslated category exposure is:

- 1,627 item rows
- 1,473 orders
- R$213,662.90 of item-side value
- R$15,843,553.24 total item-side value in the item population

### Treatment

Use a downstream category label equivalent to:

```sql
COALESCE(
    product_category_name_english,
    product_category_name,
    'unknown'
)
```

This means:

- translated English category when available;
- Portuguese source category when translation is missing;
- `unknown` only when the source category itself is null.

Do not drop these products from item or value metrics.


## 5. Geography

`raw.geolocation` cannot be treated as a one-row-per-ZIP dimension.

Observed structure:

- 1,000,163 geolocation rows
- 19,015 distinct ZIP prefixes
- 17,972 ZIP prefixes with multiple rows
- 8,555 ZIP prefixes with multiple normalized city labels
- 8 ZIP prefixes associated with more than one state
- maximum 1,146 geolocation rows for one ZIP prefix

Coverage against the geolocation source:

| Source | Rows | Unmatched rows | Unmatched ZIP prefixes |
|---|---:|---:|---:|
| customers | 99,441 | 278 | 157 |
| sellers | 3,095 | 7 | 7 |

### Treatment

Do not join customers or sellers directly to `raw.geolocation`.

Build one geographic lookup row per ZIP prefix before enrichment:

- use median latitude and longitude from available coordinate samples;
- keep customer/seller city and state as the operational location attributes;
- use geolocation primarily for coordinates;
- leave coordinates null when the ZIP prefix has no match;
- optionally flag ZIP prefixes with conflicting state information.

This prevents geographic joins from multiplying marketplace rows.


## 6. Monetary reconciliation

Item and payment measures were aggregated independently to order grain before comparison.

### Basic hygiene

Order-item rows:

- 0 negative prices
- 0 negative freight values
- 0 zero prices
- 383 zero-freight rows

Payment rows:

- 0 negative payment values
- 9 zero-payment rows
- 2 rows with zero installments

These values are retained as source observations unless a downstream metric explicitly requires otherwise.

### Order-level comparison

98,665 orders contain both item and payment records.

Comparison:

```text
item-side value = SUM(price + freight_value)
payment value   = SUM(payment_value)
```

| Difference | Orders |
|---|---:|
| Exact match | 98,089 |
| Greater than 0 and at most R$0.01 | 273 |
| Greater than R$0.01 and at most R$1 | 54 |
| Greater than R$1 | 249 |

Therefore:

- 98,362 orders agree within R$0.01;
- 303 orders differ by more than R$0.01;
- mean signed gap is R$0.0291;
- total signed gap is R$2,870.39.

Most material mismatches occur on delivered orders: 299 delivered orders differ by more than R$0.01.

### Treatment

Use three separate financial concepts:

- **Merchandise value:** `SUM(price)` at item grain
- **Item-side value including freight:** `SUM(price + freight_value)` at item grain
- **Collected payment:** `SUM(payment_value)` at payment grain

Rules:

1. Never calculate item and payment totals from an unaggregated items-payments join.
2. Treat absolute order-level differences of at most R$0.01 as rounding tolerance.
3. Flag differences greater than R$0.01 for QA.
4. Do not overwrite item-side or payment values to make them reconcile.
5. Do not exclude an order from unrelated operational metrics because its monetary totals differ.


## 7. Historical coverage

Purchase timestamps span:

```text
2016-09-04 through 2018-10-17
```

Coverage is not uniform across the entire range.

Observed boundary behavior:

- September 2016: 4 orders
- October 2016: 324 orders, ending October 22
- November 2016: no orders
- December 2016: 1 order
- January 2017: 800 orders, beginning January 5
- February 2017 through August 2018: continuous full-month coverage
- September 2018: 16 orders and 0 delivered orders
- October 2018: 4 orders and 0 delivered orders

### Treatment

For strict month-over-month operational trend comparisons, use:

```text
2017-02-01 through 2018-08-31
```

These are the continuously observed full calendar months in the extract.

January 2017 may be retained in broader descriptive views, but it should be identified as a partial boundary month because observations begin January 5.

The sparse 2016 period and September–October 2018 tail remain in the raw source and may still be used for record-level investigation, but they should not be presented as comparable monthly operating periods.


## 8. Treatment rules

The downstream analytical layer should implement the following rules explicitly.

| Area | Rule |
|---|---|
| Raw data | never modify source CSVs or `raw.*` to repair quality issues |
| Reviews | flag reused review IDs; exclude ambiguous reused-ID rows from order-level CX aggregation |
| Multiple reviews | aggregate remaining review scores to one value per order; retain review count |
| Review timing | do not use review creation minus delivery as a response-time KPI |
| Delivery KPIs | use metric-specific timestamp eligibility rather than one global row exclusion |
| Status conflicts | preserve source status and add quality flags where needed |
| Orders without items | retain for order-level analysis; exclude naturally from item-grain measures |
| Order without payments | retain for order/item analysis; exclude naturally from payment measures |
| Missing product category | label `unknown` |
| Missing category translation | preserve Portuguese category as fallback |
| Geography | collapse geolocation to one row per ZIP before joining |
| Unmatched geography | retain source city/state and leave coordinates null |
| Monetary difference ≤ R$0.01 | treat as reconciliation tolerance |
| Monetary difference > R$0.01 | flag; do not force reconciliation |
| Trend reporting | use full-month stable coverage for comparable monthly trends |


## 9. Validation

The quality-investigation runner completes successfully:

```bash
python -m python.scripts.run_quality_investigation
```

Automated validation also passes:

```text
22 passed
```

The investigation is reproducible from the raw PostgreSQL schema and does not require manual edits to the source files.


## 10. Known limitations

Some source anomalies cannot be assigned a definitive root cause from the available Olist fields alone.

In particular:

- reused review IDs cannot be conclusively explained;
- carrier-before-approval timestamps may reflect process timing, system timing, or source-record semantics;
- review creation timestamps should not be interpreted as reliable post-delivery response times;
- item-side and payment differences cannot be fully explained because the extract does not contain every possible adjustment field;
- ZIP prefixes with conflicting geolocation labels require deterministic aggregation rather than assuming one source row is correct;
- sparse boundary periods reflect extract coverage and should not be interpreted as marketplace performance.

These limitations are documented rather than silently repaired.


## Scope

This report defines data-quality findings and downstream treatment rules.

It does not build:

- analytical fact or dimension tables;
- business KPIs;
- seller rankings;
- root-cause operational analysis;
- statistical models;
- dashboards.

Those layers should consume the treatment rules defined here rather than reinterpreting raw-source anomalies independently.
