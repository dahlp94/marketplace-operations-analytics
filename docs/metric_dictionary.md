# Metric Dictionary

This document defines the business meaning, grain, formulas, populations, exclusions, null handling, and reporting dates for the project's core metrics.

SQL implementations should follow these definitions consistently.

# Governing Rules

* Use certified `analytics.*` tables.
* Reuse existing eligibility flags where available.
* Never join `fact_order_items` directly to `fact_payments` for monetary aggregation.
* Keep excluded and missing populations visible.
* Do not treat missing timestamps or missing reviews as successful outcomes.
* Keep seller performance rate, seller volume, and marketplace contribution separate.

# Core Inputs

| Metric area                    | Source                                                     |
| ------------------------------ | ---------------------------------------------------------- |
| Orders and delivery timestamps | `analytics.fact_orders`                                    |
| Order items and seller value   | `analytics.fact_order_items`                               |
| Reviews                        | `analytics.fact_reviews`, `fact_orders.order_review_score` |
| Customer identity              | `analytics.dim_customer.customer_unique_id`                |
| Calendar fields                | `analytics.dim_date`                                       |
| Fulfillment eligibility        | Existing eligibility flags in `fact_orders`                |

`customer_id` identifies an order-level customer record.

`customer_unique_id` identifies the persistent buyer and should be used for repeat-purchase analysis.

# Reporting Date

The default reporting date is:

```sql
purchase_date
```

This keeps marketplace, seller, commercial, and customer-experience metrics on the same clock.

Use another date only when the question explicitly requires it.

| Question                            | Date                 |
| ----------------------------------- | -------------------- |
| Marketplace activity                | `purchase_date`      |
| When deliveries physically occurred | actual delivery date |
| Review inflow                       | review creation date |

For comparable monthly trends, use:

```sql
purchase_date >= DATE '2017-02-01'
AND purchase_date < DATE '2018-09-01'
```

Partial boundary periods remain in the analytical population but should not be treated as full comparable months.

# Core Populations

## All Orders

Every row in:

```sql
analytics.fact_orders
```

Count: **99,441**

## Delivered Orders

```sql
order_status = 'delivered'
```

Count: **96,478**

Non-delivered orders remain available for other analyses but are excluded from delivery-performance metrics.

## Delivery-Performance Eligible

Orders that can be classified as early, on-time, or late:

```sql
order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL
AND order_estimated_delivery_date IS NOT NULL
```

Count: **96,470**

Eight delivered orders are excluded because actual delivery timestamps are missing.

## Purchase-to-Delivery Eligible

Use:

```sql
eligible_purchase_to_delivery
```

Count: **96,470**

## Seller-Handling Eligible

Use:

```sql
eligible_seller_handling
```

Count: **95,112**

Excluded delivered orders include:

* carrier handoff before approval;
* missing approval timestamp;
* missing carrier timestamp.

## Carrier-Transit Eligible

Use:

```sql
eligible_carrier_transit
```

Count: **96,281**

## Reviewed Orders

Orders with a usable order-level review score:

```sql
n_usable_review_rows > 0
```

Count: **97,530**

Orders without usable reviews remain separate rather than being treated as positive or neutral.

# Delivery Metrics

## Delivery Class

Compare calendar dates:

```sql
CASE
    WHEN order_delivered_customer_date::date
         < order_estimated_delivery_date::date
        THEN 'early'
    WHEN order_delivered_customer_date::date
         = order_estimated_delivery_date::date
        THEN 'on_time'
    WHEN order_delivered_customer_date::date
         > order_estimated_delivery_date::date
        THEN 'late'
END
```

Do not compare raw timestamps.

Estimated delivery timestamps occur at midnight, so timestamp comparison would incorrectly classify same-day deliveries as late.

| Class          | Orders |
| -------------- | -----: |
| Early          | 88,644 |
| On time        |  1,292 |
| Late           |  6,534 |
| Total eligible | 96,470 |

## On-Time Delivery Rate

> What share of eligible deliveries arrived on or before the promised date?

```text
early + on_time
----------------
eligible deliveries
```

Observed:

```text
89,936 / 96,470 = 93.23%
```

## Late Delivery Rate

```text
late deliveries
---------------
eligible deliveries
```

Observed:

```text
6,534 / 96,470 = 6.77%
```

On the same population:

```text
on_time_delivery_rate + late_delivery_rate = 1
```

## Delivery Delay Days

Signed calendar-day difference:

```sql
order_delivered_customer_date::date
- order_estimated_delivery_date::date
```

Interpretation:

```text
negative = early
0        = promised date
positive = late
```

Do not call this `late_days`.

## Late Days

Positive-only lateness:

```sql
GREATEST(delivery_delay_days, 0)
```

Early and exact-date deliveries receive 0.

# Fulfillment Durations

Use elapsed timestamp time:

```sql
EXTRACT(EPOCH FROM (end_timestamp - start_timestamp)) / 86400.0
```

This produces fractional days.

## Purchase-to-Delivery Days

```text
customer delivery - purchase
```

Population:

```sql
eligible_purchase_to_delivery
```

Observed mean: **12.56 days**

## Seller Handling Days

```text
carrier handoff - approval
```

Population:

```sql
eligible_seller_handling
```

Observed mean: **2.85 days**

Approval is the canonical start.

Do not silently replace it with purchase time.

## Carrier Transit Days

```text
customer delivery - carrier handoff
```

Population:

```sql
eligible_carrier_transit
```

Observed mean: **9.33 days**

## Promised Window Days

```sql
order_estimated_delivery_date::date
- order_purchase_timestamp::date
```

Observed mean: **24.37 days**

This measures how much delivery time was promised. It is not itself a measure of fulfillment quality.

# Seller Attribution

Orders may contain multiple sellers.

Use:

```text
seller_order = distinct (seller_id, order_id)
```

for seller-level delivery performance.

This avoids counting the same order multiple times because a seller has multiple item rows.

## Shared Order Metrics

These remain order-level and may be associated with each participating seller:

* delivery class;
* delivery delay;
* seller handling duration;
* carrier transit duration.

These are not seller-specific timestamps.

## Seller GMV

Use only the value of that seller's items:

```sql
SUM(price)
```

Do not assign the full order GMV to every seller.

# Seller Metrics

## Seller Order Volume

```text
count of distinct seller-order combinations
```

Always display volume with seller performance rates.

## Seller Late Count

Number of eligible seller-orders whose parent order was late.

## Seller Late Rate

```text
late seller-orders
------------------
eligible seller-orders
```

This measures failure frequency.

A seller with:

```text
1 late / 1 order
```

must not be interpreted the same way as:

```text
500 late / 1,000 orders
```

Volume must remain visible.

## Seller Late Contribution

```text
seller late seller-orders
-------------------------
all marketplace late seller-orders
```

This measures contribution to marketplace harm.

It is different from seller late rate.

Observed full-population denominator: **6,547 late seller-orders**

There are:

* 6,534 late orders;
* 6,547 late seller-orders.

The difference comes from multi-seller orders.

# Commercial Metrics

## GMV

Canonical project definition:

```sql
SUM(price)
```

GMV means merchandise value only.

It does not include:

* freight;
* payment value.

Certified total: **R$13,591,643.70**

## Freight Value

Keep separate from GMV.

Certified total: **R$2,251,909.54**

## Collected Payment

Keep separate from GMV.

Certified total: **R$16,008,872.12**

Payments and merchandise value represent different concepts and do not always reconcile exactly.

## Late GMV

Merchandise value associated with late eligible orders.

Observed: **R$985,924.34**

This represents value exposed to late delivery, not financial loss.

# Review Metrics

The order-level review measure is:

```sql
order_review_score
```

A negative review is:

```sql
order_review_score <= 2
```

Orders without usable reviews remain null.

## Review Coverage

For fulfillment-related customer-experience reporting:

```text
reviewed delivered orders
-------------------------
delivered orders
```

Observed:

```text
94,782 / 96,478 = 98.24%
```

Review coverage measures data availability, not customer satisfaction.

## Average Review Score

Average among reviewed orders only.

Observed: **4.09**

Do not replace missing scores with a synthetic value.

## Negative Review Rate

```text
reviews with score <= 2
-----------------------
reviewed orders
```

Observed:

```text
14,197 / 97,530 = 14.56%
```

Orders without usable reviews are excluded from both numerator and denominator.

## Review Bands

| Band     | Definition    |
| -------- | ------------- |
| Negative | score ≤ 2     |
| Neutral  | 2 < score < 4 |
| Positive | score ≥ 4     |

| Band     | Orders |
| -------- | -----: |
| Negative | 14,197 |
| Neutral  |  8,022 |
| Positive | 75,311 |

# Repeat Customers

Use:

```sql
customer_unique_id
```

Sequence orders as:

```sql
ROW_NUMBER() OVER (
    PARTITION BY customer_unique_id
    ORDER BY order_purchase_timestamp, order_id
)
```

## Customer Order Sequence

```text
1 = first observed order
2 = second observed order
3 = third observed order
...
```

## Repeat Order

```sql
customer_order_sequence > 1
```

A future repeat customer's first purchase is still a first order.

## Repeat Customer

A buyer with at least two observed orders in the extract.

| Population         |  Count |
| ------------------ | -----: |
| Buyers             | 96,096 |
| First orders       | 96,096 |
| Repeat orders      |  3,345 |
| Repeat customers   |  2,997 |
| One-time customers | 93,099 |

Do not use `customer_id` for repeat-customer analysis.

# Key Edge Cases

| Case                                   | Expected behavior                                        |
| -------------------------------------- | -------------------------------------------------------- |
| Delivered before estimate              | `early`                                                  |
| Delivered on same calendar date        | `on_time`                                                |
| Delivered after estimate               | `late`                                                   |
| Delivered but missing actual timestamp | Excluded from delivery-performance population            |
| Multi-seller order                     | One seller-order per participating seller                |
| Multi-seller late order                | Each participating seller receives one late seller-order |
| Multiple payment rows                  | Keep payments separate from item aggregation             |
| No usable review                       | Excluded from review-rate denominator                    |
| Repeat buyer's first order             | Not a repeat order                                       |
| Repeat buyer's later order             | Repeat order                                             |
| Seller with 1/1 late                   | Late rate = 100%, volume = 1                             |
| Invalid handling timestamps            | Excluded from handling duration only                     |
| Delivered order without payment        | May still participate in delivery and GMV metrics        |

# Metric Summary

| Metric                      | Grain             | Definition                                        |
| --------------------------- | ----------------- | ------------------------------------------------- |
| `on_time_delivery_rate`     | eligible order    | early + on-time / eligible                        |
| `late_delivery_rate`        | eligible order    | late / eligible                                   |
| `delivery_delay_days`       | eligible order    | actual date − estimated date                      |
| `late_days`                 | eligible order    | `GREATEST(delay, 0)`                              |
| `purchase_to_delivery_days` | eligible order    | delivery − purchase                               |
| `seller_handling_days`      | eligible order    | carrier − approval                                |
| `carrier_transit_days`      | eligible order    | delivery − carrier                                |
| `promised_window_days`      | delivered order   | estimated date − purchase date                    |
| `seller_late_rate`          | seller-order      | late seller-orders / eligible seller-orders       |
| `seller_late_contribution`  | seller-order      | seller late units / marketplace late seller units |
| `seller_gmv`                | seller-item       | `SUM(price)`                                      |
| `gmv`                       | item              | `SUM(price)`                                      |
| `late_gmv`                  | late items/orders | GMV associated with late deliveries               |
| `review_coverage`           | delivered order   | reviewed delivered / delivered                    |
| `negative_review_rate`      | reviewed order    | score ≤ 2 / reviewed                              |
| `is_repeat_order`           | order             | customer order sequence > 1                       |

# Validation Summary

The metric definitions have been checked against the certified analytical model.

| Check                                                         | Result |
| ------------------------------------------------------------- | ------ |
| Orders = 99,441                                               | PASS   |
| Delivered = 96,478                                            | PASS   |
| Delivery eligible = 96,470                                    | PASS   |
| Early + on-time + late = eligible                             | PASS   |
| On-time + late rates = 1                                      | PASS   |
| Eligible durations contain no negative values                 | PASS   |
| Seller GMV reconciles to order GMV                            | PASS   |
| Late seller-order difference explained by multi-seller orders | PASS   |
| Review populations reconcile to all orders                    | PASS   |
| First orders equal distinct buyers                            | PASS   |
| Repeat sequencing reconciles                                  | PASS   |

# Reproduction

Validate the metric definitions:

```bash
python -m python.scripts.run_metric_validation
pytest tests/test_metric_definitions.py -q
```

Validation outputs:

```text
outputs/metric_validation/
├── 01_metric_populations.txt
├── 02_metric_contract_prototypes.txt
├── 03_metric_validation_examples.txt
└── metric_validation.txt
```

Build and validate the reusable metric layer:

```bash
python -m python.scripts.build_metric_layer
python -m python.scripts.run_metric_layer_validation
pytest tests/test_metric_layer.py -q
```

The reusable implementation of these definitions is documented in [`docs/metric_layer.md`](metric_layer.md).
