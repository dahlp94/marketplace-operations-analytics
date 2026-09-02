# Relationship and Join-Safety Audit

This document records observed relationships and cardinalities among the raw Olist tables loaded into PostgreSQL schema `raw`.

The purpose is to determine which joins are structurally safe before building the analytical model. The analytical model is built separately from the raw-source audit.

---

## Core child-to-parent coverage

Raw tables have no declared foreign keys. Coverage is measured with `LEFT JOIN` checks.

| Child → parent | Child rows | Unmatched rows | Unmatched keys |
|---|---:|---:|---:|
| `orders.customer_id` → `customers.customer_id` | 99,441 | 0 | 0 |
| `order_items.order_id` → `orders.order_id` | 112,650 | 0 | 0 |
| `order_payments.order_id` → `orders.order_id` | 103,886 | 0 | 0 |
| `order_reviews.order_id` → `orders.order_id` | 99,224 | 0 | 0 |
| `order_items.seller_id` → `sellers.seller_id` | 112,650 | 0 | 0 |
| `order_items.product_id` → `products.product_id` | 112,650 | 0 | 0 |
| `products.product_category_name` → category translation | 32,951 | 13 | 2 |

The core order/customer/item/payment/review/seller/product child-to-parent relationships have complete coverage in this extract.

Category translation is incomplete: 13 product rows across 2 non-null category names do not find a translation match.

---

## Parent-child cardinalities

### Orders → order items

| Measure | Result |
|---|---:|
| Orders | 99,441 |
| Orders with 0 items | 775 |
| Orders with 1 item | 88,863 |
| Orders with 2+ items | 9,803 |
| Maximum items on one order | 21 |
| Order-item rows | 112,650 |

### Orders → payments

| Measure | Result |
|---|---:|
| Orders | 99,441 |
| Orders with 0 payment rows | 1 |
| Orders with 1 payment row | 96,479 |
| Orders with 2+ payment rows | 2,961 |
| Maximum payment rows on one order | 29 |
| Payment rows | 103,886 |

### Orders → reviews

| Measure | Result |
|---|---:|
| Orders | 99,441 |
| Orders with 0 review rows | 768 |
| Orders with 1 review row | 98,126 |
| Orders with 2+ review rows | 547 |
| Maximum review rows on one order | 3 |
| Review rows | 99,224 |

Review cardinality is not one-per-order.

### Customers → orders

`customer_id` is exactly one-to-one between `raw.customers` and `raw.orders` in this extract:

- 99,441 customer rows
- 99,441 orders
- 0 customer rows without an order
- 0 customer IDs associated with multiple orders

The durable buyer identifier is `customer_unique_id`.

### Sellers → order items

| Measure | Result |
|---|---:|
| Sellers | 3,095 |
| Sellers with 0 item rows | 0 |
| Sellers with 1 item row | 509 |
| Sellers with 2+ item rows | 2,586 |
| Maximum item rows for one seller | 2,033 |

### Products → order items

| Measure | Result |
|---|---:|
| Products | 32,951 |
| Products with 0 item rows | 0 |
| Products with 1 item row | 18,117 |
| Products with 2+ item rows | 14,834 |
| Maximum item rows for one product | 527 |

---

## Multi-seller orders

Among 98,666 orders with at least one item:

- 97,388 involve one seller
- 1,278 involve multiple sellers
- maximum sellers on one order: 5

**Implication**  
A marketplace order cannot always be attributed to a single seller. Seller-level operational analysis must be derived from item-level participation.

---

## Customer identity

Olist publishes two customer identifiers with different meanings.

| Identifier | Unique in `raw.customers`? | Interpretation |
|---|---|---|
| `customer_id` | Yes | order-scoped customer record |
| `customer_unique_id` | No | underlying buyer identifier reused across orders |

Observed counts:

- customer rows: 99,441
- distinct `customer_id`: 99,441
- distinct `customer_unique_id`: 96,096
- buyers with 1 order: 93,099
- buyers with 2 orders: 2,745
- buyers with 3+ orders: 252
- maximum observed orders for one buyer: 17

A traced buyer with the maximum observed count appears under 17 different `customer_id` values across 17 orders.

**Implication**

- use `customer_id` for the per-order relationship to `customers`
- use `customer_unique_id` for future repeat-customer and buyer-level metrics

---

## Geolocation relationship risk

`raw.geolocation` is not a unique ZIP-prefix lookup.

Observed structure:

- 1,000,163 geolocation rows
- 19,015 distinct ZIP prefixes
- maximum rows for one ZIP prefix: 1,146

A direct join from customers or sellers to raw geolocation on ZIP prefix can multiply rows.

**Implication**  
A deterministic one-row-per-ZIP mapping must be created before geolocation is used as an analytical dimension. Mapping and coverage rules will be defined during data-quality investigation and analytical modeling.

---

## Join fan-out between items and payments

### Why the join is dangerous

Both `order_items` and `order_payments` are one-to-many children of `orders`.

```text
orders
├── order_items
└── order_payments
```

They have no direct row-level relationship to each other beyond `order_id`.

Therefore:

```sql
FROM raw.order_items i
JOIN raw.order_payments p
    ON i.order_id = p.order_id
```

creates a many-to-many fan-out whenever an order has multiple rows on both sides.

Any item-grain measure is repeated once per matching payment row. Any payment-grain measure is repeated once per matching item row.

### Population with both multiple items and multiple payments

The source audit identified:

- 275 orders with at least 2 item rows and at least 2 payment rows
- 623 native item rows across that subset
- 711 native payment rows across that subset
- 1,622 rows after the naive join

### Worked example

One traced order contains:

- 7 item rows
- 3 payment rows
- 21 rows after the naive join

| Measure | Native value | After naive join | Duplication factor |
|---|---:|---:|---:|
| Item-side value (`price + freight_value`) | R$421.70 | R$1,265.10 | 3× |
| Payment value | R$421.69 | R$2,951.83 | 7× |

The one-cent difference between the native item-side and payment totals is not investigated in this source audit. The important structural result is the multiplication caused by the join.

### Dataset-wide effect

Among orders that have both item and payment records:

| Measure | Native grain | After naive items-payments join |
|---|---:|---:|
| Item rows | 112,647 | 117,601 joined rows |
| Payment rows | 103,056 | 117,601 joined rows |
| Item-side value (`price + freight_value`) | R$15,843,409.78 | R$16,566,543.85 |
| Payment value | R$15,846,280.17 | R$20,308,134.71 |

The naive join therefore overstates measures from both child tables.

### Safe analytical implication

Measures at different grains must remain separate or be aggregated to a common grain before they are combined.

For later modeling:

- keep order-item measures at item grain
- keep payment measures at payment grain
- keep review measures separate from item grain
- aggregate each child table before combining measures at order grain

---

## Representative lineage cases

| Case | What it demonstrates |
|---|---|
| 1 item, 1 payment, 1 review | simple relationship path |
| multiple items, one payment | payment duplication risk after an item join |
| one item, multiple payments | item duplication risk after a payment join |
| multi-seller order | seller attribution exists at item grain |
| order without items | child relationship can be optional |
| delivered order without payment rows | source-quality issue identified here; not treated |
| order without reviews | review coverage is incomplete |
| duplicated `review_id` across orders | `review_id` alone is not a safe row key |

---

## Analytical modeling rules

1. `orders` is the central order-level source table.
2. `order_items`, `order_payments`, and `order_reviews` remain separate child grains.
3. Never calculate item and payment totals from one unaggregated items-payments join.
4. Use `customer_unique_id` for buyer-level repeat-customer analysis.
5. Use `customer_id` for the per-order customer relationship.
6. Seller participation is derived from `order_items`; orders can involve multiple sellers.
7. Do not treat raw geolocation as a unique ZIP dimension.
8. Do not assume one review per order.
9. Do not use `review_id` alone as the review-table key.

---

## Scope and downstream use

This document establishes relationship safety only. It identifies issues but does not apply treatment rules.

The following will be resolved during data-quality investigation, or defined when the analytical model and KPI layer are built:

- treatment of missing lifecycle timestamps
- review deduplication/treatment
- geography-cleaning and coverage rules
- product-category cleanup
- payment reconciliation
- analytical KPI definitions
- fact/dimension model construction

Data-quality findings and treatment rules are documented in `docs/data_quality_report.md`. KPI definitions and the analytical model remain later work.
