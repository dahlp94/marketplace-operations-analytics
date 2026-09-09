-- Metric-layer grain and lineage constraints.

ALTER TABLE metrics.kpi_orders
    ADD PRIMARY KEY (order_id),
    ADD CONSTRAINT fk_kpi_orders_fact_orders
        FOREIGN KEY (order_id) REFERENCES analytics.fact_orders (order_id),
    ADD CONSTRAINT fk_kpi_orders_purchase_date
        FOREIGN KEY (purchase_date) REFERENCES analytics.dim_date (date_day),
    ADD CONSTRAINT chk_kpi_orders_on_time_late_complement
        CHECK (
            (NOT is_delivery_performance_eligible
                AND is_on_time IS NULL
                AND is_late IS NULL)
            OR
            (is_delivery_performance_eligible
                AND is_on_time IS NOT NULL
                AND is_late IS NOT NULL
                AND is_on_time = NOT is_late)
        ),
    ADD CONSTRAINT chk_kpi_orders_delivery_class
        CHECK (
            (NOT is_delivery_performance_eligible AND delivery_class IS NULL)
            OR
            (is_delivery_performance_eligible
                AND delivery_class IS NOT NULL
                AND delivery_class IN ('early', 'on_time', 'late'))
        ),
    ADD CONSTRAINT chk_kpi_orders_sequence
        CHECK (customer_order_sequence >= 1);

ALTER TABLE metrics.kpi_customers
    ADD PRIMARY KEY (customer_unique_id);

ALTER TABLE metrics.kpi_seller_orders
    ADD PRIMARY KEY (seller_id, order_id),
    ADD CONSTRAINT fk_kpi_seller_orders_seller
        FOREIGN KEY (seller_id) REFERENCES analytics.dim_seller (seller_id),
    ADD CONSTRAINT fk_kpi_seller_orders_order
        FOREIGN KEY (order_id) REFERENCES metrics.kpi_orders (order_id);

ALTER TABLE metrics.kpi_sellers
    ADD PRIMARY KEY (seller_id),
    ADD CONSTRAINT fk_kpi_sellers_dim_seller
        FOREIGN KEY (seller_id) REFERENCES analytics.dim_seller (seller_id);

ALTER TABLE metrics.kpi_marketplace_month
    ADD PRIMARY KEY (purchase_month);

ALTER TABLE metrics.kpi_review_bands
    ADD PRIMARY KEY (review_band);

ALTER TABLE metrics.kpi_delivery_review
    ADD PRIMARY KEY (delivery_class, review_status);
