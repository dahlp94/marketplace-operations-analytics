# Source Inventory

Inventory of the raw Olist source tables loaded into PostgreSQL schema `raw`.

This document records each table's business meaning, grain, candidate key, important relationships, null behavior, and structural observations. This inventory identifies source structure; it does not define cleaning or treatment rules.

Loaded row counts match logical CSV record counts from `python/scripts/load_raw.py`.

---

## Load summary

| Raw table | Source file | Rows | Confirmed grain | Candidate key |
|---|---|---:|---|---|
| `raw.orders` | `olist_orders_dataset.csv` | 99,441 | one row per order | `order_id` |
| `raw.order_items` | `olist_order_items_dataset.csv` | 112,650 | one row per order line | `(order_id, order_item_id)` |
| `raw.order_payments` | `olist_order_payments_dataset.csv` | 103,886 | one row per payment allocation | `(order_id, payment_sequential)` |
| `raw.order_reviews` | `olist_order_reviews_dataset.csv` | 99,224 | one row per review-order pair | `(review_id, order_id)` |
| `raw.customers` | `olist_customers_dataset.csv` | 99,441 | one row per order-scoped customer record | `customer_id` |
| `raw.sellers` | `olist_sellers_dataset.csv` | 3,095 | one row per seller | `seller_id` |
| `raw.products` | `olist_products_dataset.csv` | 32,951 | one row per product | `product_id` |
| `raw.geolocation` | `olist_geolocation_dataset.csv` | 1,000,163 | one row per geolocation sample | no unique ZIP-prefix key |
| `raw.product_category_translation` | `product_category_name_translation.csv` | 71 | one row per Portuguese category | `product_category_name` |

Raw tables intentionally have no declared primary-key or foreign-key constraints. Candidate-key uniqueness and relationship coverage are measured directly from the loaded source data.

---

## `raw.orders`

**Business meaning**  
One marketplace order.

**Grain**  
One row per order.

**Candidate key**  
`order_id` — 99,441 rows, 99,441 distinct values, 0 nulls.

**Important relationship**  
`customer_id` → `raw.customers.customer_id` with 0 unmatched order rows.

**Important columns**

- `order_id`
- `customer_id`
- `order_status`
- `order_purchase_timestamp`
- `order_approved_at`
- `order_delivered_carrier_date`
- `order_delivered_customer_date`
- `order_estimated_delivery_date`

**Source observations**

- `order_purchase_timestamp`: 0 nulls
- `order_estimated_delivery_date`: 0 nulls
- `order_approved_at`: 160 nulls
- `order_delivered_carrier_date`: 1,783 nulls
- `order_delivered_customer_date`: 2,965 nulls

Missingness varies strongly by order status. A small delivered population also has missing lifecycle timestamps, which requires further data-quality investigation.

**Structural implication**  
`orders` is the source hub. Items, payments, and reviews relate to it through `order_id`, but those child tables do not all share the same grain.

---

## `raw.order_items`

**Business meaning**  
One product line within an order, fulfilled by a seller.

**Grain**  
One row per `(order_id, order_item_id)`.

**Candidate key**  
`(order_id, order_item_id)` — 112,650 rows and 112,650 distinct composite keys.

**Important relationships**

- `order_id` → `raw.orders.order_id` with 0 unmatched rows
- `product_id` → `raw.products.product_id` with 0 unmatched rows
- `seller_id` → `raw.sellers.seller_id` with 0 unmatched rows

**Important columns**

- `order_id`
- `order_item_id`
- `product_id`
- `seller_id`
- `shipping_limit_date`
- `price`
- `freight_value`

**Source observations**

- 88,863 orders have exactly one item
- 9,803 orders have two or more items
- maximum items on one order: 21
- 775 orders have no item rows
- among orders with items, 1,278 involve multiple sellers
- maximum sellers on one order: 5
- key, seller, product, price, and freight fields profiled here have 0 nulls

**Structural implication**  
Seller participation exists at item grain. An order can contain several items and several sellers, so seller-level analysis must be built from `order_items` rather than assuming one seller per order.

---

## `raw.order_payments`

**Business meaning**  
One payment allocation associated with an order.

**Grain**  
One row per `(order_id, payment_sequential)`.

**Candidate key**  
`(order_id, payment_sequential)` — 103,886 rows and 103,886 distinct composite keys.

**Important relationship**  
`order_id` → `raw.orders.order_id` with 0 unmatched rows.

**Important columns**

- `order_id`
- `payment_sequential`
- `payment_type`
- `payment_installments`
- `payment_value`

**Source observations**

- 96,479 orders have one payment row
- 2,961 orders have two or more payment rows
- maximum payment rows on one order: 29
- 1 order has no payment row
- `payment_value` has 0 nulls in the profiled extract

**Structural implication**  
Payment measures live at payment grain. They must not be summed after an unaggregated join to `order_items`.

---

## `raw.order_reviews`

**Business meaning**  
One review row associated with an order.

**Grain**  
One row per `(review_id, order_id)` in this extract.

**Candidate-key results**

| Key tested | Rows | Distinct | Unique? |
|---|---:|---:|---|
| `review_id` | 99,224 | 98,410 | No |
| `(review_id, order_id)` | 99,224 | 99,224 | Yes |

`review_id` alone is therefore not a safe primary key for this source extract.

**Important relationship**  
`order_id` → `raw.orders.order_id` with 0 unmatched review rows.

**Important columns**

- `review_id`
- `order_id`
- `review_score`
- `review_comment_title`
- `review_comment_message`
- `review_creation_date`
- `review_answer_timestamp`

**Source observations**

- 768 orders have no review rows
- 98,126 orders have exactly one review row
- 547 orders have two or more review rows
- maximum review rows on one order: 3
- `review_id`, `order_id`, and `review_score` have 0 nulls in the profiled extract

**Structural implication**  
Review metrics must not assume one review per order, and review rows should remain separate from item-grain measures until a deliberate aggregation rule is defined.

---

## `raw.customers`

**Business meaning**  
The customer record attached to an order, including a stable buyer identifier and order-associated geography.

**Grain**  
One row per `customer_id`.

**Candidate key**  
`customer_id` — 99,441 rows and 99,441 distinct values.

`customer_unique_id` is not unique: 96,096 distinct buyer IDs appear across 99,441 customer rows.

**Relationship to orders**  
`customer_id` is exactly one-to-one with `orders.customer_id` in this extract.

**Important columns**

- `customer_id`
- `customer_unique_id`
- `customer_zip_code_prefix`
- `customer_city`
- `customer_state`

**Source observations**

- 96,096 distinct buyers
- 93,099 buyers have one order
- 2,745 buyers have two orders
- 252 buyers have three or more orders
- maximum observed orders for one buyer: 17
- `customer_unique_id` and `customer_zip_code_prefix` have 0 nulls

**Structural implication**  
Use `customer_id` for the per-order relationship to the customer table. Use `customer_unique_id` for future repeat-customer and buyer-level analysis.

Geographic coverage and mapping rules are addressed during data-quality investigation and analytical modeling. The raw geolocation source is not unique by ZIP prefix.

---

## `raw.sellers`

**Business meaning**  
One marketplace seller.

**Grain**  
One row per seller.

**Candidate key**  
`seller_id` — 3,095 rows and 3,095 distinct values.

**Important relationship**  
`seller_id` participates in `raw.order_items` at item grain. All sellers appear on at least one order item.

**Important columns**

- `seller_id`
- `seller_zip_code_prefix`
- `seller_city`
- `seller_state`

**Source observations**

- 509 sellers appear on one item row
- 2,586 sellers appear on two or more item rows
- maximum item rows associated with one seller: 2,033
- `seller_zip_code_prefix` has 0 nulls

**Structural implication**  
There is no seller-to-order table. Seller participation must be derived from `order_items`.

Geographic coverage and mapping rules are addressed during data-quality investigation and analytical modeling.

---

## `raw.products`

**Business meaning**  
One product in the marketplace catalog.

**Grain**  
One row per product.

**Candidate key**  
`product_id` — 32,951 rows and 32,951 distinct values.

**Important relationships**

- all `order_items.product_id` values match `raw.products.product_id`
- `product_category_name` may match `raw.product_category_translation.product_category_name`

**Important columns**

- `product_id`
- `product_category_name`
- `product_name_lenght`
- `product_description_lenght`
- `product_photos_qty`
- `product_weight_g`
- `product_length_cm`
- `product_height_cm`
- `product_width_cm`

The source spelling `lenght` is preserved.

**Source observations**

- 610 products have a null `product_category_name`
- 13 product rows with non-null categories do not match the translation table
- those 13 rows represent 2 distinct category names
- 18,117 products appear on one item row
- 14,834 appear on two or more item rows
- maximum item rows associated with one product: 527

**Structural implication**  
Category translation is incomplete. Future product/category analysis must avoid dropping unmatched or null-category products unintentionally.

---

## `raw.geolocation`

**Business meaning**  
Geographic coordinate samples associated with Brazilian ZIP-code prefixes.

**Grain**  
One row per geolocation sample.

**Candidate-key result**  
`geolocation_zip_code_prefix` is not unique.

**Important columns**

- `geolocation_zip_code_prefix`
- `geolocation_lat`
- `geolocation_lng`
- `geolocation_city`
- `geolocation_state`

**Source observations**

- 1,000,163 geolocation rows
- 19,015 distinct ZIP prefixes
- maximum rows for one ZIP prefix: 1,146
- `geolocation_zip_code_prefix` has 0 nulls

**Structural implication**  
`raw.geolocation` is not a one-row-per-ZIP lookup table. Joining customers or sellers directly to it on ZIP prefix can multiply rows. A deterministic one-row-per-prefix mapping must be designed later.

---

## `raw.product_category_translation`

**Business meaning**  
English translation lookup for Portuguese product category names.

**Grain**  
One row per Portuguese category name.

**Candidate key**  
`product_category_name` — 71 rows and 71 distinct values.

**Important columns**

- `product_category_name`
- `product_category_name_english`

**Source observations**

The lookup key is unique, but product-side translation coverage is incomplete: 13 product rows across 2 non-null category names do not find a translation match.

**Structural implication**  
Translation enrichment should use a left join if unmatched products must remain in the analytical population.

---

## Grain summary

| Table | Confirmed grain | Key result |
|---|---|---|
| `orders` | one row per order | `order_id` unique |
| `order_items` | one row per order line | `(order_id, order_item_id)` unique |
| `order_payments` | one row per payment allocation | `(order_id, payment_sequential)` unique |
| `order_reviews` | one row per review-order pair | `(review_id, order_id)` unique; `review_id` alone is not |
| `customers` | one row per order-scoped customer record | `customer_id` unique; `customer_unique_id` not unique |
| `sellers` | one row per seller | `seller_id` unique |
| `products` | one row per product | `product_id` unique |
| `geolocation` | one row per coordinate sample | ZIP prefix not unique |
| `product_category_translation` | one row per Portuguese category | `product_category_name` unique |

---

## Scope of this inventory

This inventory describes source structure and observed symptoms only. It does not apply treatment rules.

The following remain for data-quality investigation and analytical modeling:

- timestamp-validity treatment
- review deduplication/treatment
- geography coverage and one-row-per-ZIP mapping rules
- product-category cleanup
- payment reconciliation rules
- status-specific exclusions
- historical completeness analysis

Treatment rules and downstream handling are documented in `docs/data_quality_report.md` without changing this source inventory.