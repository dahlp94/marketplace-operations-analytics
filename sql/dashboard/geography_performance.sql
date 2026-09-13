-- Customer-destination concentration. Order grain only.

CREATE VIEW dashboard.customer_state_names AS
SELECT *
FROM (
    VALUES
        ('AC', 'Acre'), ('AL', 'Alagoas'), ('AM', 'Amazonas'), ('AP', 'Amapá'),
        ('BA', 'Bahia'), ('CE', 'Ceará'), ('DF', 'Distrito Federal'),
        ('ES', 'Espírito Santo'), ('GO', 'Goiás'), ('MA', 'Maranhão'),
        ('MG', 'Minas Gerais'), ('MS', 'Mato Grosso do Sul'), ('MT', 'Mato Grosso'),
        ('PA', 'Pará'), ('PB', 'Paraíba'), ('PE', 'Pernambuco'), ('PI', 'Piauí'),
        ('PR', 'Paraná'), ('RJ', 'Rio de Janeiro'), ('RN', 'Rio Grande do Norte'),
        ('RO', 'Rondônia'), ('RR', 'Roraima'), ('RS', 'Rio Grande do Sul'),
        ('SC', 'Santa Catarina'), ('SE', 'Sergipe'), ('SP', 'São Paulo'),
        ('TO', 'Tocantins')
) AS s(customer_state, customer_state_name);

CREATE VIEW dashboard.geography_performance AS
WITH scope_metrics AS (
    SELECT
        'full_extract'::text AS reporting_scope,
        customer_state,
        'order'::text AS unit_grain,
        all_orders,
        delivery_performance_eligible AS eligible_orders,
        late_count AS late_orders,
        late_delivery_rate AS late_rate,
        gmv,
        late_gmv,
        negative_review_rate,
        NULL::numeric AS median_seller_handling_days,
        NULL::numeric AS median_carrier_transit_days,
        NULL::numeric AS median_promised_window_days,
        delivery_performance_eligible < 100 AS is_low_sample
    FROM analysis.customer_state_performance

    UNION ALL

    SELECT
        'comparable_trend_window',
        segment_key,
        unit_grain,
        NULL::integer,
        eligible_units,
        late_units,
        late_rate,
        gmv,
        late_gmv,
        NULL::numeric,
        median_seller_handling_days,
        median_carrier_transit_days,
        median_promised_window_days,
        is_low_sample
    FROM analysis.segment_fulfillment_performance
    WHERE segment_type = 'customer_state'
)
SELECT
    g.reporting_scope,
    g.customer_state,
    COALESCE(n.customer_state_name, g.customer_state) AS customer_state_name,
    g.unit_grain,
    g.all_orders,
    g.eligible_orders,
    g.late_orders,
    g.late_rate,
    g.gmv,
    g.late_gmv,
    g.negative_review_rate,
    g.median_seller_handling_days,
    g.median_carrier_transit_days,
    g.median_promised_window_days,
    g.is_low_sample,
    g.late_orders::numeric
        / NULLIF(SUM(g.late_orders) OVER (PARTITION BY g.reporting_scope), 0)
        AS late_share_of_scope
FROM scope_metrics g
LEFT JOIN dashboard.customer_state_names n USING (customer_state);

CREATE VIEW dashboard.geography_month AS
SELECT
    m.segment_key AS customer_state,
    COALESCE(n.customer_state_name, m.segment_key) AS customer_state_name,
    m.purchase_month,
    m.unit_grain,
    'comparable_trend_window'::text AS reporting_scope,
    m.eligible_units AS eligible_orders,
    m.late_units AS late_orders,
    m.late_rate,
    m.gmv,
    m.late_gmv,
    t.late_count AS marketplace_late_orders,
    m.late_units::numeric / NULLIF(t.late_count, 0) AS late_share_of_month,
    m.median_seller_handling_days,
    m.median_carrier_transit_days,
    m.median_promised_window_days,
    m.is_low_sample,
    m.segment_key = 'RJ'
        AND m.late_rate > 0.20
        AND m.eligible_units >= 500 AS meets_rj_monitoring_rule
FROM analysis.segment_fulfillment_month m
JOIN analysis.marketplace_month_trend t USING (purchase_month)
LEFT JOIN dashboard.customer_state_names n
    ON n.customer_state = m.segment_key
WHERE m.segment_type = 'customer_state';
