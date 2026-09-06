-- Enforce analytical grains and core relationships.

ALTER TABLE analytics.dim_date
    ADD PRIMARY KEY (date_day),
    ADD UNIQUE (date_key);

ALTER TABLE analytics.dim_geography
    ADD PRIMARY KEY (zip_code_prefix);

ALTER TABLE analytics.dim_customer
    ADD PRIMARY KEY (customer_id);

ALTER TABLE analytics.dim_seller
    ADD PRIMARY KEY (seller_id);

ALTER TABLE analytics.dim_product
    ADD PRIMARY KEY (product_id);

ALTER TABLE analytics.fact_orders
    ADD PRIMARY KEY (order_id);

ALTER TABLE analytics.fact_order_items
    ADD PRIMARY KEY (order_id, order_item_id);

ALTER TABLE analytics.fact_payments
    ADD PRIMARY KEY (order_id, payment_sequential);

ALTER TABLE analytics.fact_reviews
    ADD PRIMARY KEY (review_id, order_id);


ALTER TABLE analytics.dim_customer
    ADD CONSTRAINT fk_dim_customer_geography
    FOREIGN KEY (zip_code_prefix)
    REFERENCES analytics.dim_geography (zip_code_prefix);

ALTER TABLE analytics.dim_seller
    ADD CONSTRAINT fk_dim_seller_geography
    FOREIGN KEY (zip_code_prefix)
    REFERENCES analytics.dim_geography (zip_code_prefix);

ALTER TABLE analytics.fact_orders
    ADD CONSTRAINT fk_fact_orders_customer
    FOREIGN KEY (customer_id)
    REFERENCES analytics.dim_customer (customer_id),
    ADD CONSTRAINT fk_fact_orders_purchase_date
    FOREIGN KEY (purchase_date)
    REFERENCES analytics.dim_date (date_day);

ALTER TABLE analytics.fact_order_items
    ADD CONSTRAINT fk_fact_order_items_order
    FOREIGN KEY (order_id)
    REFERENCES analytics.fact_orders (order_id),
    ADD CONSTRAINT fk_fact_order_items_product
    FOREIGN KEY (product_id)
    REFERENCES analytics.dim_product (product_id),
    ADD CONSTRAINT fk_fact_order_items_seller
    FOREIGN KEY (seller_id)
    REFERENCES analytics.dim_seller (seller_id);

ALTER TABLE analytics.fact_payments
    ADD CONSTRAINT fk_fact_payments_order
    FOREIGN KEY (order_id)
    REFERENCES analytics.fact_orders (order_id);

ALTER TABLE analytics.fact_reviews
    ADD CONSTRAINT fk_fact_reviews_order
    FOREIGN KEY (order_id)
    REFERENCES analytics.fact_orders (order_id);
