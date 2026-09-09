# KPI Certification

This document certifies the reusable metric and analysis layers for downstream operational analysis.

The certification question is:

> Can `metrics.*` and `analysis.*` be trusted as the sole analytical input for root-cause investigation, statistical inference, and an Operations dashboard?

Certification independently recalculates core contracts from certified `analytics.*` tables. Production KPI views are compared, not reused as the calculation source.

Metric definitions remain in [`docs/metric_dictionary.md`](metric_dictionary.md). Table grains remain in [`docs/metric_layer.md`](metric_layer.md) and [`docs/analysis_layer.md`](analysis_layer.md).

## Certification decision

**Certified for downstream root-cause and operational analysis.**

No blocking defects were found.

Marketplace KPIs, seller contribution, commercial values, review denominators, repeat-customer sequencing, time-series windows, and rankings reconcile to independent calculations. Expected non-equalities at different grains are documented below and do not indicate inflation.

## Certification matrix

| Metric | Output | Grain | Numerator | Denominator | Source population | Implementation | Independent validation | Status |
|---|---|---|---|---|---|---|---|---|
| On-time delivery | `metrics.kpi_orders`, `metrics.kpi_marketplace` | eligible order | early + exact-date | delivery-performance eligible | delivered orders with actual and estimated dates | `sql/metrics/10_kpi_orders.sql`, `14_kpi_marketplace.sql` | date comparison from `analytics.fact_orders` | PASS |
| Late delivery | same | eligible order | late | delivery-performance eligible | same | same | same | PASS |
| Delivery delay | `metrics.kpi_orders` | eligible order | actual date − estimated date | eligible order | same | `sql/metrics/10_kpi_orders.sql` | row-level date difference from `fact_orders` | PASS |
| Purchase-to-delivery days | `metrics.kpi_orders`, `kpi_marketplace` | eligible order | customer delivery − purchase | `eligible_purchase_to_delivery` | 96,470 orders | `sql/metrics/10_kpi_orders.sql` | `EXTRACT(EPOCH)` from `fact_orders` | PASS |
| Seller handling days | same | eligible order | carrier − approval | `eligible_seller_handling` | 95,112 orders | same | same | PASS |
| Carrier transit days | same | eligible order | customer delivery − carrier | `eligible_carrier_transit` | 96,281 orders | same | same | PASS |
| Seller late rate | `metrics.kpi_sellers` | seller | late seller-orders | eligible seller-orders | participating `(seller_id, order_id)` | `sql/metrics/12_kpi_seller_orders.sql`, `13_kpi_sellers.sql` | rebuild from `fact_order_items` + `fact_orders` | PASS |
| Seller late contribution | `metrics.kpi_sellers`, `analysis.seller_contribution` | seller | seller late units | 6,547 marketplace late seller-orders | late seller-orders | `sql/metrics/13_kpi_sellers.sql`, `sql/analysis/20_seller_positioning.sql` | independent seller-order count; shares sum to 1 | PASS |
| GMV / value | `metrics.kpi_orders`, seller and category tables | item / seller-item | `SUM(price)` | not a rate | all item rows | `sql/metrics/10_kpi_orders.sql` | `SUM(price)` from `fact_order_items` | PASS |
| Review coverage | `metrics.kpi_marketplace` | delivered order | reviewed delivered | delivered | delivered orders | `sql/metrics/14_kpi_marketplace.sql` | `n_usable_review_rows > 0` on `fact_orders` | PASS |
| Negative review rate | `metrics.kpi_orders`, `kpi_marketplace` | reviewed order | score ≤ 2 | reviewed orders | orders with a usable score | `sql/metrics/10_kpi_orders.sql` | unreviewed rows stay null | PASS |
| Repeat-customer classification | `metrics.kpi_orders`, `kpi_customers` | order / buyer | sequence > 1 | all orders for that buyer | `customer_unique_id` | `sql/metrics/10_kpi_orders.sql`, `11_kpi_customers.sql` | `ROW_NUMBER()` from `fact_orders` + `dim_customer` | PASS |
| Rolling 30 / 90 day | `analysis.marketplace_day`, `analysis.seller_day_rolling` | date / seller-date | window SUM(numerator) | window SUM(denominator) | purchase-date calendar range | `sql/analysis/11_rolling_windows.sql` | brute-force `BETWEEN` from `analytics.*` | PASS |

## Analytical populations

Independent recalculation from `analytics.fact_orders` matched the KPI layer exactly:

| Population | Independent | KPI |
|---:|---:|---:|
| All orders | 99,441 | 99,441 |
| Delivered | 96,478 | 96,478 |
| Delivery-performance eligible | 96,470 | 96,470 |
| Missing actual delivery | 8 | 8 |
| Early | 88,644 | 88,644 |
| Exact-date on-time | 1,292 | 1,292 |
| On-time (early + exact) | 89,936 | 89,936 |
| Late orders | 6,534 | 6,534 |
| Purchase-to-delivery eligible | 96,470 | 96,470 |
| Seller-handling eligible | 95,112 | 95,112 |
| Carrier-transit eligible | 96,281 | 96,281 |
| Reviewed orders | 97,530 | 97,530 |
| Reviewed delivered | 94,782 | 94,782 |
| Negative reviews | 14,197 | 14,197 |
| First orders / buyers | 96,096 | 96,096 |
| Repeat orders | 3,345 | 3,345 |

Observed rates:

```text
on-time delivery rate     89,936 / 96,470 = 93.23%
late delivery rate         6,534 / 96,470 =  6.77%
review coverage           94,782 / 96,478 = 98.24%
negative review rate      14,197 / 97,530 = 14.56%
```

Duration means also matched:

| Measure | Mean days |
|---|---:|
| Purchase-to-delivery | 12.56 |
| Seller handling | 2.85 |
| Carrier transit | 9.33 |
| Delivery delay (signed) | −11.88 |

Merchandise GMV, freight, collected payment, and late GMV all reconcile:

| Measure | Amount |
|---|---:|
| GMV | R$13,591,643.70 |
| Freight | R$2,251,909.54 |
| Collected payment | R$16,008,872.12 |
| Late GMV | R$985,924.34 |

Every order-level delivery class, late flag, delay, duration, and negative-review flag matched the independent `analytics.*` calculation. Mismatch counts were 0.

## Validation methodology

Certification SQL lives under `sql/kpi_certification/` and is narrower than implementation-time validation.

```text
sql/kpi_certification/
├── 01_independent_marketplace.sql
├── 02_seller_category_geography.sql
├── 03_windows_rankings_customers.sql
├── 04_structural_qa.sql
└── 05_query_plans.sql
```

The checks answer:

1. Do marketplace KPIs reproduce from `analytics.fact_orders` without reading KPI formulas as the source of truth?
2. Do seller, category, and geography totals reconcile at the grain the contract requires?
3. Do selected `LAG()` and rolling windows reproduce from brute-force date ranges?
4. Do rankings, repeat sequences, and review denominators hold on full populations and traced examples?
5. Are grains unique, rates bounded, and joins free of unexplained fan-out?
6. Are representative query plans acceptable at this extract's scale?

Existing layer validation under `sql/metrics/validate/` and `sql/analysis/validate/` remains complementary, not a substitute for these independent checks.

## Seller reconciliation

Because 1,278 orders involve multiple sellers, marketplace order counts and seller-order counts are different grains.

| Relationship | Left | Right | Should match? | Result |
|---|---:|---:|---|---|
| Late orders vs late seller-orders | 6,534 | 6,547 | no | expected gap |
| Late seller-orders = late orders + extra multi-seller units | 6,547 | 6,547 | yes | 13 extra units from 13 multi-seller late orders |
| Independent late seller-orders vs `kpi_sellers` | 6,547 | 6,547 | yes | PASS |
| Seller GMV vs item `SUM(price)` | R$13,591,643.70 | R$13,591,643.70 | yes | PASS |
| Seller-order volume vs all orders | 100,010 | 99,441 | no | multi-seller orders counted once per seller |
| Contribution shares | 1 | 1 | yes | PASS |

All 3,095 seller rows matched the independent rebuild for late count, eligible volume, GMV, late rate, and contribution.

Contribution uses late **seller-orders**, not late orders. Cumulative contribution is monotonic and ends at 1.

## Category and geography

Category GMV is item-additive and reconciles to marketplace GMV.

Category late **counts** are not additive. A seller-order can contain more than one product category, so the same late seller-order can appear in more than one category row.

| Measure | Value | Additive? |
|---|---:|---|
| Category GMV | R$13,591,643.70 | yes |
| Late seller-category rows | 6,560 | no |
| Marketplace late seller-orders | 6,547 | seller-order grain |

The 13-row gap is the same kind of multi-membership effect already accepted for multi-seller orders.

Geography summaries preserve grain:

- customer-state late counts sum to 6,534 late **orders**
- seller-state late units sum to 6,547 late **seller-orders**
- both GMV totals reconcile
- joining `kpi_orders` → `dim_customer` → `dim_geography` does not multiply rows (99,441 = 99,441)

## Time series and rankings

Independent monthly totals from `fact_orders` matched `metrics.kpi_marketplace_month`.

| Check | Result |
|---|---|
| February 2017 comparable prior | null |
| February 2017 calendar `LAG()` prior | present (partial January 2017) |
| March 2017 percentage-point change | matches independent `new − old` |
| 2018-05-15 rolling 30d | 391 late / 7,665 eligible |
| 2018-05-15 rolling 90d | 2,563 late / 21,422 eligible |
| Extract-start 30d / 90d windows | flagged as partial |
| High-volume seller 30d brute-force | matches `analysis.seller_day_rolling` |

Ranking functions were reproduced for every seller:

- `RANK` / `DENSE_RANK` / `ROW_NUMBER` / `PERCENT_RANK` mismatches = 0
- 51 sellers with a 100% late rate share one `RANK` and one `DENSE_RANK`, and keep 51 distinct `ROW_NUMBER` values
- 536 sellers with one eligible order remain visible

Ranks remain descriptive. They are not intervention scores.

## Repeat customers and reviews

Traced buyers:

| Buyer | Orders | Result |
|---|---:|---|
| `0000366f3b9a7992bf8c76cfdf3221e2` | 1 | sequence = 1; not a repeat order |
| `00172711b30d52eea8b313a7f2cced02` | 2 | first, then repeat |
| `8d50f5eadf50201ccdcedfb9e2ac8455` | 17 | sequences 1–17 match |
| `02b20b7c813efede140142ac610e36dc` | 2 at the same timestamp | `order_id` tie-break: `25ce3a22…` is first |

Full-population sequence mismatches: **0**.

Review bands independently reproduce (14,197 / 8,022 / 75,311). Unreviewed orders never receive `is_negative_review`. The delivered review mix covers all 96,478 delivered orders and keeps 1,696 delivered orders without a usable review visible.

## Structural QA

Every reusable output checked had unique grain keys. There were no null keys, negative counts, rates outside `[0, 1]`, contribution shares outside `[0, 1]`, duration values on ineligible rows, seller-order orphans, or rolling-window duplicate dates.

Item→product, order→customer, and seller-order→seller joins did not multiply rows.

## Query plans and indexing

`EXPLAIN ANALYZE` was run on representative workloads. Existing indexes are primary keys only.

| Query | Scan / join | Window / sort | Runtime | Indexes used |
|---|---|---|---:|---|
| Marketplace delivery aggregation | Parallel seq scan of `fact_orders` | aggregate only | 41 ms | none needed |
| Seller-order grain | Index scan of `fact_order_items_pkey` | incremental sort + group | 318 ms | PK `(order_id, order_item_id)` |
| Marketplace rolling 30/90 | Parallel seq scan + hash aggregate | `RANGE` window | 43 ms | none needed |
| Seller rolling 30d | Seq scan of `kpi_seller_orders` | hash aggregate + 3.6 MB disk sort + window | 952 ms | none |
| Category join | Seq scan + hash join to `dim_product` | 10.6 MB disk sort | 2.1 s | none |
| Geography join | Parallel hash join of orders/customers; seq scan of `dim_geography` | small hash aggregate | 140 ms | none; join remains 1:1 |
| Contribution ranking | Seq scan of 3,095 sellers | in-memory sort + window | 27 ms | none needed |

### Useful now

None.

These queries run during documented rebuilds, not as interactive dashboard filters. The longest plan is about two seconds on a 25 MB item table. Adding indexes would not change any certified number and would not materially change local rebuild time.

### Production-scale consideration

Likely useful if this model were applied to a much larger order stream:

- `(seller_id, purchase_date)` on `metrics.kpi_seller_orders` for seller rolling windows
- `purchase_date` on `analytics.fact_orders` / `metrics.kpi_orders` for date-range and month grouping
- higher `work_mem` so seller-day and category sorts stay in memory

### Not justified

- table partitioning
- covering indexes on ranking or contribution tables
- BRIN indexes on a 100-thousand-row extract
- any index added only to make the portfolio look “production-tuned”

No index or partitioning change was implemented.

## Reproducibility

From the certified analytical model:

```bash
./scripts/setup_local_postgres.sh

python -m python.scripts.build_metric_layer
python -m python.scripts.build_analysis_layer

python -m python.scripts.run_metric_layer_validation
python -m python.scripts.run_analysis_validation
python -m python.scripts.run_kpi_certification

pytest tests/test_metric_layer.py tests/test_analysis_layer.py tests/test_kpi_certification.py -q
pytest -q
```

No notebook state or manual SQL is required.

Evidence is written to:

```text
outputs/kpi_certification/
```

## Test result

```text
72 passed
```

## Known caveats

These are documented contracts, not defects:

- late orders (6,534) and late seller-orders (6,547) must not be forced equal
- category late counts can exceed marketplace late seller-orders when one seller-order spans categories
- seller volume is never dropped to make rates look more stable
- `seller_negative_review_rate` is order-level customer experience associated with participating sellers
- `first_observed_activity_cohort` is first observed purchase month, not verified onboarding
- comparable month-over-month analysis uses 2017-02 through 2018-08; other months remain visible
- eight delivered orders remain excluded from delivery-performance metrics because the actual delivery timestamp is missing
- unreviewed orders are excluded from the negative-review denominator

## Blockers

None.

## Downstream use

The certified KPI and analysis layers may be used as the only metric input for:

- root-cause framing of late delivery and review outcomes
- seller, category, and geography contribution analysis
- time-series description of marketplace and seller performance
- later statistical inference, if separately authorized

They must not be silently rewritten downstream. If a later result is wrong, ownership returns to the earliest layer that defined the grain or formula.
