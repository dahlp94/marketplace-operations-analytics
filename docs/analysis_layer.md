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
analysis.fulfillment_month
analysis.fulfillment_decomposition
analysis.segment_fulfillment_performance
analysis.segment_fulfillment_month
analysis.seller_prioritization
analysis.seller_watchlist
analysis.seller_volume_threshold_sensitivity
analysis.review_coverage
analysis.review_score_distribution
analysis.delay_band_reviews
analysis.review_selection
analysis.delivery_review_month
analysis.segment_review_performance
```

Rebuild:

```bash
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_analysis_validation
pytest tests/test_analysis_layer.py tests/test_fulfillment_root_cause.py tests/test_seller_concentration.py tests/test_customer_experience.py -q
```

Independent certification of the metric and analysis layers is documented in [`docs/kpi_certification.md`](kpi_certification.md).

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

# Fulfillment decomposition extracts

These tables reuse certified duration and delivery-class fields. They do not redefine them.

| Table | Grain | Use |
|---|---|---|
| `analysis.fulfillment_month` | purchase month | Marketplace late rate with mean, median, and p90 handling, transit, promise, and purchase-to-delivery times |
| `analysis.fulfillment_decomposition` | `(analysis_period, delivery_class)` | Late versus early versus exact-date component comparison |
| `analysis.segment_fulfillment_performance` | `(segment_type, segment_key)` | Comparable-window category, customer-state, and seller-activity-cohort summaries |
| `analysis.segment_fulfillment_month` | `(segment_type, segment_key, purchase_month)` | The same segments over time |

`analysis_period` is either `comparable_trend_window` or `full_extract`.

Category rows use the certified seller-order-category grain. A seller-order can appear in more than one category if it contains more than one category. Customer-state rows use the order grain.

Segments with eligible volume below 100 are flagged `is_low_sample`. Monthly segment rows use a 50-order threshold.

Seller handling, carrier transit, and promised-window days remain separate columns with their own eligibility counts. They are not added together into a new fulfillment score.

Preliminary findings from these extracts are in [`docs/root_cause_analysis.md`](root_cause_analysis.md).

# Seller concentration extracts

These tables reuse certified seller-order late units, rates, contribution, and seller-item GMV. They add expected and excess late seller-orders.

| Table | Grain | Use |
|---|---|---|
| `analysis.seller_prioritization` | seller | Certified volume, rate, contribution, value, reviews, recent trend, plus excess late under marketplace, category, destination, and seller-state benchmarks |
| `analysis.seller_watchlist` | seller | Candidate investigation set with explicit reason flags |
| `analysis.seller_volume_threshold_sensitivity` | minimum eligible volume | How late-unit coverage changes as low-volume sellers are set aside |

The primary excess formula is:

```text
expected = eligible seller-orders × (6,547 / 97,811)
excess   = observed late seller-orders − expected
```

Late rate and contribution remain separate columns. The watchlist is not a composite score.

Findings are in [`docs/seller_concentration.md`](seller_concentration.md).

# Customer experience extracts

These tables reuse certified delivery class, delay days, review scores, negative-review flags, GMV, and repeat-order fields. They do not redefine them.

Reviews remain at the order grain. Missing reviews stay visible and are never coded as negative.

| Table | Grain | Use |
|---|---|---|
| `analysis.review_coverage` | population | Certified review denominators, including delivered coverage and first versus repeat missingness |
| `analysis.review_score_distribution` | `(delivery_class, review_score)` | Score mix among eligible reviewed orders |
| `analysis.delay_band_reviews` | delay band | Negative-review rate by how early or late the order arrived |
| `analysis.review_selection` | reviewed vs unreviewed delivered orders | Whether missing reviews are associated with worse delivery |
| `analysis.delivery_review_month` | purchase month | Whether the late-review relationship changes during spike and promise-compression months |
| `analysis.segment_review_performance` | `(segment_type, segment_key)` | Sequence, GMV band, customer state, and primary-category splits, with early versus late rates |

`analysis.delivery_review_mix` and `analysis.delivery_class_review_rates` remain the certified delivery-by-review cross-tabs.

Primary category is the order's largest-GMV category, so a review is counted once. Segments with fewer than 100 reviewed orders are flagged `is_low_sample`.

Findings are in [`docs/customer_experience_analysis.md`](customer_experience_analysis.md).
