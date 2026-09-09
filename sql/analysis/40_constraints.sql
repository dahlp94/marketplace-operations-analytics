-- Keys and relationships for analysis tables.

ALTER TABLE analysis.reporting_month
    ADD PRIMARY KEY (purchase_month);

ALTER TABLE analysis.marketplace_month_trend
    ADD PRIMARY KEY (purchase_month);

ALTER TABLE analysis.seller_month
    ADD PRIMARY KEY (seller_id, purchase_month),
    ADD FOREIGN KEY (seller_id)
        REFERENCES analytics.dim_seller (seller_id);

ALTER TABLE analysis.marketplace_day
    ADD PRIMARY KEY (purchase_date),
    ADD FOREIGN KEY (purchase_date)
        REFERENCES analytics.dim_date (date_day);

ALTER TABLE analysis.seller_day_rolling
    ADD PRIMARY KEY (seller_id, purchase_date),
    ADD FOREIGN KEY (seller_id)
        REFERENCES analytics.dim_seller (seller_id);

ALTER TABLE analysis.seller_rankings
    ADD PRIMARY KEY (seller_id),
    ADD FOREIGN KEY (seller_id)
        REFERENCES analytics.dim_seller (seller_id);

ALTER TABLE analysis.seller_contribution
    ADD PRIMARY KEY (seller_id),
    ADD UNIQUE (contribution_row_number);

ALTER TABLE analysis.seller_category
    ADD PRIMARY KEY (seller_id, product_category);

ALTER TABLE analysis.category_performance
    ADD PRIMARY KEY (product_category);

ALTER TABLE analysis.seller_first_observed
    ADD PRIMARY KEY (seller_id);

ALTER TABLE analysis.seller_cohort_summary
    ADD PRIMARY KEY (first_observed_activity_cohort);

ALTER TABLE analysis.customer_state_performance
    ADD PRIMARY KEY (customer_state);

ALTER TABLE analysis.seller_state_performance
    ADD PRIMARY KEY (seller_state);

ALTER TABLE analysis.repeat_order_performance
    ADD PRIMARY KEY (order_sequence_band);

ALTER TABLE analysis.delivery_review_mix
    ADD PRIMARY KEY (delivery_class, review_status);

ALTER TABLE analysis.delivery_class_review_rates
    ADD PRIMARY KEY (delivery_class);
