# Analytical Data Model

This document describes the reusable analytical model built from the Olist marketplace source data.

The purpose of the model is simple:

> Allow downstream analysis to calculate marketplace KPIs without re-solving source grain, data-quality, geography, category, or join problems.

The model does not define business KPIs, seller rankings, root-cause findings, or dashboard logic. Those analyses consume this model.

## Architecture

```text
raw.*
    ↓
stg.*
    ↓
analytics.*
    ↓
KPIs and analysis
```

- `raw` preserves the source extracts.
- `stg` applies only reusable quality treatments and safe mappings.
- `analytics` provides dimensions, native-grain facts, and safe order-level rollups.

Raw tables are never rewritten.

Rebuild and validate the model with:

```bash
python -m python.scripts.build_analytical_model
python -m python.scripts.run_model_validation
pytest -q
```

## Design principles

### Preserve native grain

Orders, items, payments, and reviews remain separate because they have different grains.

```text
fact_orders
├── fact_order_items
├── fact_payments
└── fact_reviews
```

A direct item-to-payment join on `order_id` can multiply monetary values. For that reason, child facts are aggregated independently before order-level totals are added to `fact_orders`.

### Apply treatments only where they are reusable

The staging layer does not contain KPI logic. It only carries treatments that later analyses will repeatedly need, such as:

- metric-specific order eligibility;
- review-ID reuse flags;
- safe ZIP-level geolocation;
- product-category fallback logic.

### Keep analysis rules visible

The comparable monthly trend window is not stored as a permanent model flag. Trend analyses explicitly filter:

```sql
WHERE purchase_date >= DATE '2017-02-01'
  AND purchase_date < DATE '2018-09-01'
```

This keeps reporting assumptions visible where they are used.

## Tables

| Schema | Table | Grain |
|---|---|---|
| `stg` | `geolocation_zip` | one ZIP prefix |
| `stg` | `orders` | one order |
| `stg` | `order_items` | one order line |
| `stg` | `order_payments` | one payment allocation |
| `stg` | `order_reviews` | one review-order pair |
| `stg` | `products` | one product |
| `analytics` | `dim_date` | one calendar date |
| `analytics` | `dim_geography` | one observed ZIP prefix |
| `analytics` | `dim_customer` | one order-scoped customer record |
| `analytics` | `dim_seller` | one seller |
| `analytics` | `dim_product` | one product |
| `analytics` | `fact_orders` | one order |
| `analytics` | `fact_order_items` | one order line |
| `analytics` | `fact_payments` | one payment allocation |
| `analytics` | `fact_reviews` | one review-order pair |

# Staging layer

## `stg.geolocation_zip`

**Purpose:** Convert raw geolocation into a safe one-row-per-ZIP lookup.

**Grain:** One row per ZIP prefix.

**Source:** `raw.geolocation`

For each ZIP prefix:

- latitude = median latitude;
- longitude = median longitude;
- source row count is retained;
- prefixes with multiple states are flagged.

This prevents customer and seller joins from multiplying rows.

## `stg.orders`

**Purpose:** Preserve order lifecycle fields and apply approved quality rules.

**Grain:** One row per `order_id`.

**Source:** `raw.orders`

The table preserves source status and timestamps and adds:

- `carrier_before_approval`
- `carrier_before_purchase`
- `customer_delivery_before_carrier`
- `has_status_timestamp_conflict`
- `eligible_on_time_delivery`
- `eligible_purchase_to_delivery`
- `eligible_seller_handling`
- `eligible_carrier_transit`

Rows are not removed because one metric-specific timestamp is missing or invalid.

## `stg.order_items`

**Purpose:** Preserve item-grain merchandise and freight values.

**Grain:** One row per `(order_id, order_item_id)`.

**Source:** `raw.order_items`

Adds:

```text
item_side_value = price + freight_value
```

No item/payment joins occur here.

## `stg.order_payments`

**Purpose:** Preserve payment-grain collected-payment records.

**Grain:** One row per `(order_id, payment_sequential)`.

**Source:** `raw.order_payments`

Payment values are retained as observed and are not forced to reconcile with item totals.

## `stg.order_reviews`

**Purpose:** Preserve review rows while identifying ambiguous reused review IDs.

**Grain:** One row per `(review_id, order_id)`.

**Source:** `raw.order_reviews`

Adds `review_id_reused`.

All review rows remain available. Order-level CX aggregation excludes reused review IDs.

## `stg.products`

**Purpose:** Apply the approved category fallback rule.

**Grain:** One row per `product_id`.

**Source:** `raw.products` joined to `raw.product_category_translation`

Category assignment is:

```sql
COALESCE(
    product_category_name_english,
    product_category_name,
    'unknown'
)
```

`category_assignment` records whether the result is `translated`, `portuguese_fallback`, or `unknown`.

Products are not dropped because category information is missing.

# Dimensions

## `analytics.dim_date`

**Grain:** One calendar date.

Contains reusable calendar attributes such as date key, year, quarter, month, month name, ISO week, day of week, and weekend indicator.

## `analytics.dim_geography`

**Grain:** One ZIP prefix observed in geolocation, customers, or sellers.

Contains median latitude/longitude, source-row count, conflicting-state flag, and `geo_unmatched`.

Customer or seller ZIP prefixes absent from raw geolocation are retained with null coordinates.

## `analytics.dim_customer`

**Grain:** One `customer_id`.

Contains `customer_id`, `customer_unique_id`, ZIP prefix, city, and state.

`customer_id` is the order-scoped key. `customer_unique_id` can repeat and is used for repeat-buyer analysis.

## `analytics.dim_seller`

**Grain:** One `seller_id`.

Contains seller ID, ZIP prefix, city, and state.

Seller participation in orders comes from `fact_order_items`.

## `analytics.dim_product`

**Grain:** One `product_id`.

Contains product attributes plus the treated category fields from `stg.products`.

# Facts

## `analytics.fact_orders`

**Purpose:** Main order-grain operational fact.

**Grain:** One row per `order_id`.

Child tables are aggregated independently before they are joined to orders.

Important measures include:

| Column | Meaning |
|---|---|
| `n_items` | item rows on the order |
| `n_sellers` | distinct participating sellers |
| `merchandise_value` | sum of item prices |
| `freight_value` | sum of item freight |
| `item_side_value` | merchandise plus freight |
| `n_payment_rows` | payment allocations |
| `collected_payment` | summed payment value |
| `payment_item_gap` | collected payment minus item-side value |
| `monetary_diff_gt_tolerance` | absolute gap greater than R$0.01 |
| `n_review_rows` | all review rows |
| `n_usable_review_rows` | review rows without reused review IDs |
| `order_review_score` | mean score from usable review rows |

The fact also retains the approved lifecycle-quality and metric-eligibility flags from `stg.orders`.

## `analytics.fact_order_items`

**Grain:** One `(order_id, order_item_id)`.

Contains order ID, product ID, seller ID, shipping-limit timestamp, price, freight, and item-side value.

Use this fact for seller, product, category, and item-level analysis.

## `analytics.fact_payments`

**Grain:** One `(order_id, payment_sequential)`.

Contains payment type, installment count, and payment value.

## `analytics.fact_reviews`

**Grain:** One `(review_id, order_id)`.

Contains review score, comment fields, timestamps, and `review_id_reused`.

For order-level CX analysis, use `fact_orders.order_review_score`.

# Geography resolution

Raw geolocation contains many records per ZIP prefix, so direct joins are unsafe.

The model first collapses raw geolocation to one row per ZIP using median latitude and longitude. Customer and seller ZIPs absent from raw geolocation are then added to `dim_geography` with null coordinates.

Validated unmatched counts:

- 278 customer rows;
- 7 seller rows.

# Fan-out prevention

The model never joins item and payment facts directly for monetary aggregation.

Safe order-level reconciliation is:

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

These relationships are checked in the model-validation SQL.

# Quality rules carried forward

| Field | Table | Meaning |
|---|---|---|
| `eligible_on_time_delivery` | `fact_orders` | delivered order with customer-delivery timestamp |
| `eligible_purchase_to_delivery` | `fact_orders` | valid purchase-to-delivery sequence |
| `eligible_seller_handling` | `fact_orders` | valid approval-to-carrier sequence |
| `eligible_carrier_transit` | `fact_orders` | valid carrier-to-customer sequence |
| `has_status_timestamp_conflict` | `fact_orders` | source status/timestamp disagreement |
| `monetary_diff_gt_tolerance` | `fact_orders` | item-side/payment gap exceeds R$0.01 |
| `review_id_reused` | `fact_reviews` | review ID occurs on multiple rows |
| `geo_unmatched` | `dim_geography` | ZIP absent from raw geolocation |
| `has_conflicting_states` | `dim_geography` | raw geolocation assigns multiple states to a ZIP |
| `category_assignment` | `dim_product` | translated, Portuguese fallback, or unknown |

# Known limitations

The model preserves rather than hides unresolved source limitations:

- reused review IDs cannot be explained from the extract;
- some lifecycle timestamps have inconsistent ordering;
- review creation time is not treated as a reliable post-delivery response clock;
- item/payment differences cannot always be explained;
- some ZIP prefixes have conflicting geolocation labels;
- 2016 and September-October 2018 have sparse historical coverage.

# Reproduction

```bash
python -m python.scripts.load_raw
python -m python.scripts.build_analytical_model
python -m python.scripts.run_model_validation
pytest -q
```

The analytical relationship diagram is in [`docs/analytical_er_diagram.md`](analytical_er_diagram.md).
