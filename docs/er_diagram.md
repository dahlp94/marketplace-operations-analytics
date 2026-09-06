# Source Relationship Diagram

This diagram represents the raw Olist tables after loading into PostgreSQL.

This is a source-level relationship diagram, not the final analytical model.

```mermaid
erDiagram
    ORDERS ||--|| CUSTOMERS : "customer_id"
    ORDERS ||--o{ ORDER_ITEMS : "order_id"
    ORDERS ||--o{ ORDER_PAYMENTS : "order_id"
    ORDERS ||--o{ ORDER_REVIEWS : "order_id"

    SELLERS ||--|{ ORDER_ITEMS : "seller_id"
    PRODUCTS ||--|{ ORDER_ITEMS : "product_id"

    PRODUCTS }o--o| CATEGORY_TRANSLATION : "category name"
    CUSTOMERS }o--o{ GEOLOCATION : "zip prefix; non-unique"
    SELLERS }o--o{ GEOLOCATION : "zip prefix; non-unique"

    ORDERS {
        text order_id
        text customer_id
        text order_status
        timestamp purchase_timestamp
        timestamp approved_at
        timestamp delivered_carrier_date
        timestamp delivered_customer_date
        timestamp estimated_delivery_date
    }

    CUSTOMERS {
        text customer_id
        text customer_unique_id
        text zip_prefix
        text city
        text state
    }

    ORDER_ITEMS {
        text order_id
        int order_item_id
        text product_id
        text seller_id
        numeric price
        numeric freight_value
    }

    ORDER_PAYMENTS {
        text order_id
        int payment_sequential
        text payment_type
        numeric payment_value
    }

    ORDER_REVIEWS {
        text review_id
        text order_id
        int review_score
    }

    SELLERS {
        text seller_id
        text zip_prefix
        text city
        text state
    }

    PRODUCTS {
        text product_id
        text product_category_name
    }

    CATEGORY_TRANSLATION {
        text product_category_name
        text product_category_name_english
    }

    GEOLOCATION {
        text zip_prefix
        numeric lat
        numeric lng
        text city
        text state
    }
```

## Key interpretation

- `orders` is the source hub.
- `order_items`, `order_payments`, and `order_reviews` are separate child grains.
- `order_items` has observed unique key `(order_id, order_item_id)`.
- `order_payments` has observed unique key `(order_id, payment_sequential)`.
- `order_reviews` has observed unique key `(review_id, order_id)`; `review_id` alone is not unique.
- `customer_id` is one-to-one with orders in this extract.
- `customer_unique_id` identifies the underlying buyer and can repeat across orders.
- one order can contain multiple sellers through `order_items`.
- `geolocation` is not unique by ZIP prefix and should not be treated as a direct one-row-per-ZIP dimension.
- category translation is optional because product-side translation coverage is incomplete.

## Join-safety note

`order_items` and `order_payments` should not be joined directly on `order_id` and then aggregated without first controlling their grains. Both are one-to-many children of `orders`, so a naive join can duplicate item and payment measures.

The analytical model is documented in [`docs/analytical_er_diagram.md`](analytical_er_diagram.md) and [`docs/data_model.md`](data_model.md).
