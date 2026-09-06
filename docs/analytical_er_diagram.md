# Analytical Relationship Diagram

This diagram shows the grain-safe analytical model built from the Olist source data.

The model keeps order items, payments, and reviews as separate child facts so their one-to-many relationships do not create fan-out.

## Table grains

| Table | Grain |
|---|---|
| `dim_date` | one calendar date |
| `dim_geography` | one ZIP prefix |
| `dim_customer` | one order-scoped `customer_id` |
| `dim_seller` | one `seller_id` |
| `dim_product` | one `product_id` |
| `fact_orders` | one order |
| `fact_order_items` | one `(order_id, order_item_id)` |
| `fact_payments` | one `(order_id, payment_sequential)` |
| `fact_reviews` | one `(review_id, order_id)` |

```mermaid
erDiagram
    DIM_DATE ||--o{ FACT_ORDERS : "purchase_date"
    DIM_CUSTOMER ||--|| FACT_ORDERS : "customer_id"

    DIM_GEOGRAPHY ||--o{ DIM_CUSTOMER : "zip_code_prefix"
    DIM_GEOGRAPHY ||--o{ DIM_SELLER : "zip_code_prefix"

    FACT_ORDERS ||--o{ FACT_ORDER_ITEMS : "order_id"
    FACT_ORDERS ||--o{ FACT_PAYMENTS : "order_id"
    FACT_ORDERS ||--o{ FACT_REVIEWS : "order_id"

    DIM_PRODUCT ||--o{ FACT_ORDER_ITEMS : "product_id"
    DIM_SELLER ||--o{ FACT_ORDER_ITEMS : "seller_id"

    FACT_ORDERS {
        text order_id PK
        text customer_id FK
        date purchase_date FK
        text order_status
        int n_items
        int n_sellers
        numeric merchandise_value
        numeric item_side_value
        numeric collected_payment
        numeric order_review_score
        boolean monetary_diff_gt_tolerance
        boolean eligible_on_time_delivery
        boolean eligible_purchase_to_delivery
        boolean eligible_seller_handling
        boolean eligible_carrier_transit
    }

    FACT_ORDER_ITEMS {
        text order_id PK
        int order_item_id PK
        text product_id FK
        text seller_id FK
        numeric price
        numeric freight_value
        numeric item_side_value
    }

    FACT_PAYMENTS {
        text order_id PK
        int payment_sequential PK
        text payment_type
        int payment_installments
        numeric payment_value
    }

    FACT_REVIEWS {
        text review_id PK
        text order_id PK
        int review_score
        boolean review_id_reused
    }

    DIM_CUSTOMER {
        text customer_id PK
        text customer_unique_id
        text zip_code_prefix FK
        text city
        text state
    }

    DIM_SELLER {
        text seller_id PK
        text zip_code_prefix FK
        text city
        text state
    }

    DIM_PRODUCT {
        text product_id PK
        text product_category
        text category_assignment
    }

    DIM_GEOGRAPHY {
        text zip_code_prefix PK
        numeric latitude
        numeric longitude
        int n_geolocation_rows
        boolean has_conflicting_states
        boolean geo_unmatched
    }

    DIM_DATE {
        date date_day PK
        int date_key
        int year
        int quarter
        int month
        boolean is_weekend
    }
```

## Cardinality notes

- `fact_orders` has one row per order.
- `customer_id` is order-scoped, so each order points to one row in `dim_customer`.
- `customer_unique_id` can repeat across customer-dimension rows and is used for repeat-buyer analysis.
- `fact_order_items`, `fact_payments`, and `fact_reviews` are independent one-to-many children of `fact_orders`.
- `review_id` alone is not unique; the review fact key is `(review_id, order_id)`.
- Geography becomes safe to join only after raw geolocation is collapsed to one row per ZIP prefix.

## Join-safety rule

Do not join `fact_order_items` directly to `fact_payments` and then aggregate monetary values.

Use the native fact for line-level analysis or use the pre-aggregated order-level measures in `fact_orders`.
