# Foundation Certification

This document certifies the raw-to-analytics foundation used for marketplace KPI and business analysis.

The certification question is:

> Can the analytical model be trusted to preserve source populations, monetary values, approved treatments, and known edge cases without hidden rewrites or fan-out?

Certification is based on independent recalculation from `raw`, monetary reconciliation, treatment recalculation, sample lineage, model validation, and automated tests.

## Certification decision

**Certified for downstream KPI and operational analysis.**

No blocking defects were found.

Core entity counts, order-status populations, and monetary totals reconcile to raw source data. Approved quality treatments reproduce independently from raw tables, known source anomalies remain visible, and the model rebuilds from documented commands without notebook state.

## Source reconciliation

| Source | Analytical representation | Result |
|---|---|---|
| `raw.orders` | `analytics.fact_orders` | exact row match |
| `raw.customers` | `analytics.dim_customer` | exact row match |
| `raw.sellers` | `analytics.dim_seller` | exact row match |
| `raw.products` | `analytics.dim_product` | exact row match |
| `raw.order_items` | `analytics.fact_order_items` | exact row match |
| `raw.order_payments` | `analytics.fact_payments` | exact row match |
| `raw.order_reviews` | `analytics.fact_reviews` | exact row match |
| `raw.geolocation` | `stg.geolocation_zip` → `analytics.dim_geography` | many raw rows collapsed safely to one ZIP row |

Important identity counts also reconcile:

- 99,441 order-scoped customer rows
- 96,096 distinct `customer_unique_id` buyers
- 3,095 sellers
- 32,951 products

`customer_unique_id` is intentionally not unique in `dim_customer`.

## Status preservation

Source order-status populations are unchanged:

| Status | Orders |
|---|---:|
| delivered | 96,478 |
| shipped | 1,107 |
| canceled | 625 |
| unavailable | 609 |
| invoiced | 314 |
| processing | 301 |
| created | 5 |
| approved | 2 |

No order status is rewritten during transformation. Data-quality treatments affect eligibility flags, not source labels.

## Monetary reconciliation

Source monetary values are preserved exactly through the analytical model.

| Measure | Raw | Analytical native | Order rollup |
|---|---:|---:|---:|
| Merchandise value | R$13,591,643.70 | R$13,591,643.70 | R$13,591,643.70 |
| Freight value | R$2,251,909.54 | R$2,251,909.54 | R$2,251,909.54 |
| Item-side value | R$15,843,553.24 | R$15,843,553.24 | R$15,843,553.24 |
| Collected payment | R$16,008,872.12 | R$16,008,872.12 | R$16,008,872.12 |

Raw item price, freight, and review-score values are not silently rewritten.

Independent raw recalculation of item-side value versus payment value found:

| Result | Orders |
|---|---:|
| Comparable orders | 98,665 |
| Exact match | 98,089 |
| Difference within R$0.01 | 273 |
| Difference greater than R$0.01 | 303 |

Net signed gap: **R$2,870.39**

The analytical `monetary_diff_gt_tolerance` flag reproduces the same 303 orders. Values are preserved rather than forced to reconcile.

## Treatment certification

Material treatment rules were independently recalculated from raw tables and matched the analytical model.

| Treatment | Certified result |
|---|---:|
| On-time delivery eligibility | 96,470 |
| Purchase-to-delivery eligibility | 96,470 |
| Seller-handling eligibility | 95,112 |
| Carrier-transit eligibility | 96,281 |
| Reused review rows | 1,603 |
| Products assigned `unknown` category | 610 |
| Products using Portuguese fallback | 13 |
| Customer rows with unmatched geolocation | 278 |
| Seller rows with unmatched geolocation | 7 |
| Orders in comparable full-month trend window | 98,292 |

The comparable trend window is applied explicitly as:

```sql
WHERE purchase_date >= DATE '2017-02-01'
  AND purchase_date < DATE '2018-09-01'
```

It is an analysis rule, not a stored exclusion flag.

## Join and grain safety

The analytical model preserves separate native grains:

```text
fact_orders
├── fact_order_items
├── fact_payments
└── fact_reviews
```

Items and payments are never joined directly for monetary aggregation.

Safe reconciliations are:

```text
SUM(fact_order_items.price)
    =
SUM(fact_orders.merchandise_value)

SUM(fact_order_items.item_side_value)
    =
SUM(fact_orders.item_side_value)

SUM(fact_payments.payment_value)
    =
SUM(fact_orders.collected_payment)
```

Geolocation is collapsed to one row per ZIP prefix before customer or seller enrichment, so geography joins do not multiply rows.

Database constraints and model-validation SQL separately enforce and verify the documented analytical grains and foreign-key relationships.

## Known source cases retained

Certification confirmed that important edge cases survive raw → staging → analytics without unexpected loss or duplication.

| Case | Result |
|---|---|
| Multi-item order | item rows and totals preserved |
| Multi-payment order | payment rows and totals preserved |
| Multi-seller order | seller participation preserved at item grain |
| Delivered order with no payment | retained with `n_payment_rows = 0` and null `collected_payment` |
| Reused review ID | rows retained and `review_id_reused = TRUE` |
| Material item/payment mismatch | source values retained and mismatch flagged |
| Delivered order missing customer-delivery timestamp | row retained and excluded only from metrics requiring that timestamp |

## Accepted limitations

These are source limitations, not transformation defects:

- reused `review_id` values cannot be explained from the extract;
- 1,359 carrier-before-approval sequences exist;
- 23 delivered orders record customer delivery before carrier handoff;
- 8 delivered orders are missing customer-delivery timestamps;
- review creation time is not treated as a reliable post-delivery response clock;
- 303 orders differ by more than R$0.01 between item-side and payment value;
- 278 customer rows and 7 seller rows have ZIP prefixes absent from geolocation;
- some ZIP prefixes have conflicting geolocation state labels;
- 2016 and September–October 2018 have sparse historical coverage;
- one delivered order has no payment rows;
- 775 orders have no item rows.

No synthetic seller-SLA values are included in the analytical model.

## Certification checks

Certification SQL is intentionally narrower than model validation.

```text
sql/certification/
├── 01_source_reconciliation.sql
├── 02_monetary_reconciliation.sql
├── 03_treatment_recalculation.sql
└── 04_sample_lineage.sql
```

These checks independently answer:

1. Did source populations survive raw → analytics?
2. Did monetary values remain unchanged?
3. Do material treatment rules reproduce directly from raw?
4. Do known difficult records retain correct lineage?

Structural grain, referential integrity, geography joins, and fan-out protection are validated separately under `sql/analytics/validate/`.

## Reproducibility

From a clean loaded source:

```bash
./scripts/setup_local_postgres.sh

python -m python.scripts.download_raw
python -m python.scripts.load_raw

python -m python.scripts.build_analytical_model
python -m python.scripts.run_model_validation
python -m python.scripts.run_certification

pytest -q
```

Certification evidence is written to:

```text
outputs/certification/
```

No notebook state or manual SQL is required.

## Test result

```text
42 passed
```

## Downstream use

The certified foundation supports:

| Analysis | Safe usage |
|---|---|
| On-time delivery | use `eligible_on_time_delivery` |
| Purchase-to-delivery duration | use `eligible_purchase_to_delivery` |
| Seller handling time | use `eligible_seller_handling` and seller participation from `fact_order_items` |
| Carrier transit time | use `eligible_carrier_transit` |
| Merchandise / GMV-style analysis | use item-grain `price` or order-grain `merchandise_value` |
| Collected payment | use `fact_payments.payment_value` or `fact_orders.collected_payment` |
| Review analysis | use `fact_orders.order_review_score` for order-level CX |
| Repeat-customer analysis | use `customer_unique_id`, not `customer_id` |
| Geography analysis | join customer/seller ZIPs to `dim_geography` |

The foundation is considered frozen unless downstream analysis uncovers a material upstream defect.
