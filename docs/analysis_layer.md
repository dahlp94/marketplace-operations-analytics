# Analysis Layer

This document describes the advanced SQL analysis tables.

They consume the certified KPI layer and do not redefine on-time, late, GMV, review, or repeat-customer definitions.

```text
metrics.*
    ↓
analysis.reporting_month
analysis.marketplace_month_trend
analysis.seller_month
analysis.marketplace_day
analysis.seller_day_rolling
analysis.seller_rankings
analysis.seller_contribution
analysis.seller_category
analysis.customer_state_performance
analysis.repeat_order_performance
analysis.delivery_review_mix
```

Rebuild:

```bash
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_analysis_validation
pytest tests/test_analysis_layer.py -q
```

# Time basis and comparable periods

Canonical date remains `purchase_date`.

| Coverage class | Months | Use |
|---|---|---|
| `full_comparable` | 2017-02 through 2018-08 | Month-over-month comparisons |
| `partial_start` | 2017-01 | Visible; not a full comparable month |
| `sparse_start` | 2016-09 through 2016-12 | Visible; not comparable |
| `sparse_tail` | 2018-09 through 2018-10 | Visible; no delivered orders |

Incomplete months are retained in `analysis.reporting_month`. Comparable `LAG()` values are also stored separately so February 2017 does not treat January 2017 as a prior full month.

# Window function semantics

## Marketplace month-over-month

- `PARTITION BY`: none
- `ORDER BY`: `purchase_month`
- First month: `prior_*` and change fields are null
- `late_rate_pp_change` is a percentage-point change (`new - old`), not a percent change
- `comparable_late_rate_pp_change` lags only inside the full-comparable window

## Seller month-over-month

- `PARTITION BY`: `seller_id`
- `ORDER BY`: `purchase_month`
- Change is versus the seller's previous **observed** month
- `months_since_prior_activity` shows whether that prior month was adjacent

## Rolling 30 / 90 day

- Calendar `RANGE` frames, not N-row frames
- 30-day: current date and the previous 29 calendar days
- 90-day: current date and the previous 89 calendar days
- Numerator and denominator are summed in the same window, then divided
- `is_full_30d_window` / `is_full_90d_window` mark dates with a complete lookback from the extract start

# Ranking semantics

| Function | Behavior |
|---|---|
| `RANK()` | Ties share a rank; the next rank is skipped |
| `DENSE_RANK()` | Ties share a rank; the next rank is consecutive |
| `ROW_NUMBER()` | Unique order; remaining ties broken by `seller_id` |
| `PERCENT_RANK()` | Among sellers with eligible volume > 0; null otherwise |

Volume remains on every seller ranking row. A 1-eligible-order seller can have a rank of 1 and is not removed.

Ranks are not intervention scores.

# Contribution

Units are late **seller-orders**, matching the certified KPI definition (6,547), not late orders (6,534).

Cumulative contribution is computed in a unique Pareto order:

`late_seller_orders DESC, seller_late_gmv DESC, seller_id`

and uses `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.

# Category and cohorts

A seller is not forced into one category. Performance grain is `(seller_id, product_category)`. `is_largest_gmv_category` is the seller's largest observed merchandise share.

Seller cohorts use `first_observed_activity_cohort`. That is the month of the seller's first observed purchase in this extract. It is not a verified onboarding date.

# Geography and CX

Customer and seller summaries use certified `state` attributes. ZIP is joined to `dim_geography` only as a 1:1 unmatched-geo diagnostic.

Repeat and delivery-review tables reuse certified metric flags. They are descriptive. They are not hypothesis tests.
