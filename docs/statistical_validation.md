# Statistical Validation and Uncertainty

## Objective

Determine whether the main descriptive findings from fulfillment, seller concentration, and customer experience are precise enough to support operational conclusions.

All rates reuse certified KPI numerators and denominators. The methods here add uncertainty, adjusted associations, and sensitivity checks. They do not redefine on-time, late, review, or seller-order logic.

Results are observational. They are not causal effects.


## Questions

1. Are the headline late-delivery and negative-review rates estimated precisely?
2. Is the late-versus-early negative-review gap large relative to sampling uncertainty?
3. Are the fulfillment spike months and the seller watchlist distinguishable from noise?
4. Does late delivery remain associated with negative reviews after adjusting for order value, purchase sequence, customer state, and multi-seller structure?
5. Do these conclusions change under reasonable sensitivity checks?


## Methods

| Method | Use |
| ------ | --- |
| Wilson 95% interval | Binomial rates |
| Wald interval and two-proportion z comparison | Differences in rates |
| Nonparametric bootstrap, 2,000 resamples, seed 0 | Order-level and seller-clustered uncertainty for selected gaps |
| Logistic regression | Adjusted association between delivery performance and a negative-review indicator |

The review model population is delivery-performance-eligible orders with a usable review. Unreviewed orders are excluded because the outcome is undefined, not because they are treated as positive.

Reference categories:

```text
delivery class: early
GMV band:       < R$50
customer state: SP
```

Delay severity collapses all early bands into one reference group so the late bands can be compared directly to early delivery.

Bootstrap resampling units:

```text
order          independent-order resampling
primary_seller cluster resampling; primary seller is the highest-item-GMV seller on the order
```

The seller cluster is a dependence check. It is not a claim that the primary seller caused the review.


## 1. Headline Rates Are Precise

Comparable-window marketplace late rate:

```text
6,509 / 95,453 = 6.82%
95% Wilson CI: 6.66%–6.98%
```

Certified seller-order late rate:

```text
6,547 / 97,811 = 6.69%
95% Wilson CI: 6.54%–6.85%
```

Negative-review rates among reviewed eligible orders:

| Delivery class | Reviewed | Rate   | 95% CI        |
| -------------- | -------: | -----: | ------------- |
| Early          |   87,203 |  9.11% | 8.92%–9.30%   |
| On time        |    1,264 | 12.26% | 10.57%–14.19% |
| Late           |    6,307 | 62.34% | 61.14%–63.53% |

These intervals are narrow because the denominators are large. Sampling variation is not a plausible explanation for the descriptive CX split.


## 2. The Review Gap Is Large Relative to Uncertainty

Late minus early negative-review rate:

```text
53.23 percentage points
95% Wald CI: 52.02–54.44
n = 6,307 late vs 87,203 early
```

Even a 1–3 day delay remains a large gap:

```text
31.97% − 9.11% = 22.86 percentage points
95% CI: 20.72–25.00
n = 1,833 vs 87,203
```

Order-level bootstrap (seed 0, 2,000 resamples) for the late-minus-early gap:

```text
53.23% (52.00%–54.46%)
```

Seller-clustered bootstrap of the same gap:

```text
53.23% (51.89%–54.59%)
```

Clustering by primary seller widens the interval only slightly. The gap remains far from zero under both resampling schemes.

Review missingness is also distinguishable from noise, but it is a much smaller operational quantity:

```text
unreviewed late rate − reviewed late rate = 6.73 percentage points
95% CI: 5.10–8.36
n = 1,696 vs 94,774
```

Unreviewed eligible orders are about twice as late as reviewed ones, so the review model is estimated on a slightly more on-time sample. That is a limitation of the outcome, not a reason to impute missing reviews.


## 3. Fulfillment Spikes and the Watchlist Remain Distinguishable

Versus the early comparable baseline (February–August 2017: 747 / 21,247 = 3.52%):

| Period            | Late rate | Difference vs baseline | 95% CI        |
| ----------------- | --------: | ---------------------: | ------------- |
| November 2017     |    12.40% |                 +8.89 pp | 8.09–9.68 pp |
| February–March 2018 |  16.62% |                +13.11 pp | 12.44–13.78 pp |
| August 2018       |     6.19% |                 +2.67 pp | 2.03–3.31 pp |

The two deterioration episodes are far larger than sampling variation. August is also above the early baseline, but the increase is much smaller, which is consistent with a different failure mode rather than a second transit shock.

Watchlist pooled seller-order late rate:

```text
1,408 / 15,359 = 9.17%
95% CI: 8.72%–9.63%
```

That interval does not overlap the marketplace seller-order interval (6.54%–6.85%). Versus all other sellers, the watchlist is 2.93 percentage points higher (95% CI 2.45–3.42) and 3.25 percentage points above other sellers with at least 100 eligible seller-orders (95% CI 2.75–3.76).

Individual watchlist intervals matter. Several high-excess sellers have late-rate intervals entirely above the marketplace benchmark. Some recent-deterioration sellers have lifetime intervals that overlap or fall below that benchmark. The watchlist remains an investigation queue, not a set of sellers whose lifetime rates are all statistically elevated.


## 4. The Adjusted Association Remains Large

Logistic model:

```text
negative review ~ delivery class + GMV band + repeat order
                + customer state group + multi-seller flag
```

Population: 94,774 reviewed eligible orders; 12,032 negative reviews (12.70%).

Late versus early delivery:

```text
adjusted odds ratio = 16.92
95% CI: 15.98–17.91
```

Exact on-time versus early is much smaller (OR 1.47; 95% CI 1.24–1.74).

Average predicted negative-review probabilities match the descriptive rates in direction and magnitude:

| Delivery class | Observed | Predicted |
| -------------- | -------: | --------: |
| Early          |    9.11% |     9.11% |
| On time        |   12.26% |    12.26% |
| Late           |   62.34% |    62.34% |

A second specification replaces delivery class with delay severity. Adjusted odds ratios versus early:

| Delay band      | Odds ratio | 95% CI       |
| --------------- | ---------: | ------------ |
| 1–3 days late   |       4.92 | 4.45–5.45    |
| 4–7 days late   |      21.63 | 19.50–24.00  |
| 8–14 days late  |      41.71 | 36.51–47.64  |
| 15–30 days late |      44.56 | 37.82–52.48  |
| 31+ days late   |      20.88 | 16.48–26.45  |

The 31+ day band is still far above early delivery, but it is not higher than the 15–30 day band. That matches the descriptive CX finding and is why delay should not be treated as a perfectly monotonic linear effect.

McFadden pseudo-R² is 0.15. Delivery performance is a large association, not a complete explanation of review outcomes.

Pearson residuals with absolute value above 3 occur mainly where the review disagrees with delivery class: late orders with non-negative reviews, and early orders with negative reviews. Those cases are expected leftover variation, not a reason to discard the delivery association.


## 5. Sensitivity Does Not Reverse the Conclusion

Late-versus-early negative-review gap and adjusted odds ratio:

| Slice                 |     n | Rate gap | Odds ratio | 95% CI       |
| --------------------- | ----: | -------: | ---------: | ------------ |
| All reviewed eligible | 94,774 |   53.23 pp |      16.92 | 15.98–17.91 |
| Exclude 31+ day delay | 94,452 |   52.93 pp |      16.77 | 15.82–17.77 |
| Exclude p99 delay     | 93,869 |   50.61 pp |      15.32 | 14.43–16.26 |
| Comparable window     | 93,799 |   53.23 pp |      16.95 | 16.01–17.94 |
| Add category group    | 94,774 |   53.23 pp |      17.01 | 16.06–18.00 |

No reviewed eligible orders were missing a primary category label, so a complete-category restriction does not change the sample.

Extreme delays amplify the association but do not create it. Adding product-category groups does not absorb the late-delivery coefficient.


## Operational Interpretation

The descriptive conclusions survive uncertainty and adjustment:

* Late delivery is associated with a much higher negative-review rate, and the gap is estimated precisely.
* Delay severity matters, including short delays, but the relationship is not perfectly monotonic at the extreme tail.
* The November 2017 and February–March 2018 late-rate increases are far larger than sampling variation.
* The 25-seller watchlist has a higher pooled late rate than other sellers, while individual seller intervals show why the list is an investigation queue rather than a penalty ranking.
* Review missingness is informative and should keep the review model from being treated as a random sample of all delivered orders.

These results support prioritizing fulfillment reliability for customer-experience reasons. They do not estimate the causal effect of making a late order on time, and they do not assign blame to a specific seller or carrier.


## Limitations

* Orders are not independent. Shared sellers, destinations, and calendar periods can induce dependence. The seller-clustered bootstrap is a partial check, not a full hierarchical model.
* The review model drops unreviewed orders. Those orders are more often late, so the modeled population is slightly selected.
* Logistic odds ratios are not percentage-point effects. Predicted probabilities are the more operational scale.
* Primary seller is a convenience clustering unit on multi-seller orders.
* Customer state is grouped into SP, RJ, MG, and other. “Other” is a heterogeneous residual.
* No interaction model is presented. The descriptive CX analysis already showed the late-review gap inside GMV, geography, and sequence slices.
* The analysis does not identify a causal effect.


## Reproduction

```bash
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_statistical_validation
python -m python.scripts.run_analysis_validation
pytest tests/test_statistical_validation.py -q
```

Primary artifacts:

```text
sql/analysis/statistical_validation.sql
python/scripts/statistical_validation.py
python/scripts/run_statistical_validation.py
python/notebooks/statistical_validation.ipynb

outputs/analysis/review_effect_estimates.csv
outputs/analysis/group_comparisons.csv
outputs/analysis/bootstrap_estimates.csv
outputs/analysis/review_outcome_model.csv
outputs/analysis/statistical_sensitivity.csv

outputs/figures/stat_rate_intervals.png
outputs/figures/stat_group_differences.png
outputs/figures/stat_model_odds_ratios.png
```
