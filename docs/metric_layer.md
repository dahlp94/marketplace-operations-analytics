# Metric Layer

This document describes the reusable KPI tables built from the certified analytical model.

The tables implement the contracts in [`docs/metric_dictionary.md`](metric_dictionary.md). They do not redefine those contracts.

```text
analytics.*
    ↓
metrics.kpi_orders
    ├── metrics.kpi_customers
    ├── metrics.kpi_seller_orders
    │       └── metrics.kpi_sellers
    └── metrics.kpi_marketplace
        metrics.kpi_marketplace_month
        metrics.kpi_review_bands
        metrics.kpi_delivery_review
```

Rebuild:

```bash
python -m python.scripts.build_metric_layer
python -m python.scripts.run_metric_layer_validation
pytest tests/test_metric_layer.py -q
```

# Grains

| Table                           | Grain                                       | Retains ineligible rows?                    |
| ------------------------------- | ------------------------------------------- | ------------------------------------------- |
| `metrics.kpi_orders`            | one `order_id`                              | yes; metric fields are null when ineligible |
| `metrics.kpi_customers`         | one `customer_unique_id`                    | yes                                         |
| `metrics.kpi_seller_orders`     | one `(seller_id, order_id)`                 | yes; parent eligibility is flagged          |
| `metrics.kpi_sellers`           | one `seller_id`                             | yes; volume is never dropped                |
| `metrics.kpi_marketplace`       | one extract row                             | exclusion counts included                   |
| `metrics.kpi_marketplace_month` | one `purchase_month`                        | incomplete months retained                  |
| `metrics.kpi_review_bands`      | one `review_band`                           | reviewed orders only                        |
| `metrics.kpi_delivery_review`   | delivered `(delivery_class, review_status)` | unclassified and unreviewed remain visible  |

`purchase_date` is the canonical reporting date.

Monthly tables use:

```sql
DATE_TRUNC('month', purchase_date)
```

`is_comparable_trend_window` marks the period from 2017-02-01 through 2018-08-31 without removing other months.

# Join Safety

* Item rows are aggregated to `(seller_id, order_id)` before order-level fulfillment metrics are attached.
* Seller GMV is `SUM(price)` for that seller's items only.
* `fact_order_items` is never joined directly to `fact_payments`.
* Whole-order GMV is not copied to each seller-order as a summable measure.

# Seller Metrics

`seller_late_rate` uses eligible seller-orders.

`seller_late_contribution` uses late seller-order units. The marketplace denominator is **6,547 seller-orders**, not **6,534 late orders**.

`seller_negative_review_rate` represents order-level customer experience associated with participating sellers. It should not be interpreted as a seller-specific review measure.

Seller tables are not ranked at this layer.

# Auditability

`metrics.kpi_orders` retains every certified order.

`delivery_performance_exclusion_reason` can be:

* `not_delivered`
* `missing_actual_delivery`
* `missing_estimated_delivery`
* null when eligible

Duration fields are null when their corresponding eligibility condition is not satisfied.

Existing quality flags remain available on the order row.

Advanced trend, ranking, and contribution tables are documented in [`docs/analysis_layer.md`](analysis_layer.md).

# Independent Validation

Validation queries independently recalculate selected metrics from:

* `analytics.fact_orders`
* `analytics.fact_order_items`
* `analytics.dim_customer`

and compare them with the `metrics.*` outputs.

Validation evidence is stored in:

```text
outputs/metric_layer/
```

Independent certification of these tables against `analytics.*` is documented in [`docs/kpi_certification.md`](kpi_certification.md).
