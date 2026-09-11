# Operational Findings and Intervention Framework

## 1. Analytical objective

Based on the validated fulfillment, seller, customer-experience, and statistical analyses:

> Where should Operations focus attention first, why, and how would success be measured?

This document does not introduce new metrics. Every headline number is taken from certified KPI fields or approved analysis outputs. Findings are observational associations. They are not causal effects or estimated treatment impacts.


## 2. Key findings

### Finding 1 — Two different late-delivery problems, not one marketplace shock

**Population:** delivery-performance-eligible orders  
**Period:** comparable window, February 2017–August 2018 (95,453 orders; 6,509 late; late rate 6.82%, 95% CI 6.66%–6.98%)  
**Metric:** order late rate  
**Comparison:** later episodes versus February–August 2017 baseline (747 / 21,247 = 3.52%)

| Episode | Late / eligible | Late rate | vs baseline | Difference CI | Late GMV |
| ------- | --------------: | --------: | ----------: | ------------- | -------: |
| November 2017 | 904 / 7,288 | 12.40% | +8.89 pp | — | R$126,218 |
| February–March 2018 | 2,254 / 13,558 | 16.62% | +13.11 pp | 12.44–13.78 | R$314,172 |
| August 2018 | 393 / 6,351 | 6.19% | +2.67 pp | — | — |

November 2017 and February–March 2018 are large transit-associated spikes. The simplified statistical validation formally retains the February–March comparison versus the early-2017 baseline. August 2018 is above baseline, but much smaller and associated with tighter promises rather than slower fulfillment.

**Source:** `docs/root_cause_analysis.md`; `outputs/analysis/group_comparisons.csv`; `docs/statistical_validation.md`


### Finding 2 — The main spikes are concentrated in carrier transit and Rio de Janeiro destinations

**Population:** comparable-window eligible orders  
**Period:** February 2017–August 2018, with emphasis on February–March 2018  
**Metric:** median fulfillment components and customer-state late rate  
**Comparison:** late versus early orders; Rio de Janeiro versus the marketplace

Comparable-window medians:

| Delivery class | Seller handling | Carrier transit | Promised window |
| -------------- | --------------: | --------------: | --------------: |
| Early | 1.78 days | 6.93 days | 24 days |
| Late | 3.07 days | 26.17 days | 23 days |

Carrier transit is the largest separation. Seller handling is elevated among late orders but secondary. Promised windows are similar for the typical late order.

Rio de Janeiro:

```text
Comparable window: 1,495 / 12,350 = 12.11% late
February 2018:       299 / 879    = 34.02%
March 2018:          298 / 864    = 34.49%
```

Rio accounted for 597 of 2,254 February–March late orders (26.5%). São Paulo has more late orders overall because of volume (1,820 / 40,494 = 4.49%) but a much lower rate during those months.

Category mix does not explain the spikes. High-volume categories have similar late rates (about 6.5–7.5%). Extreme delays amplify the pattern: excluding the top 1% of transit times lowers the window late rate from 6.82% to 5.89%, but November, February, and March remain elevated.

**Source:** `docs/root_cause_analysis.md`; `analysis.fulfillment_month`; `analysis.segment_fulfillment_performance`


### Finding 3 — August 2018 is a promise-compression problem, concentrated in São Paulo

**Population:** comparable-window eligible orders, São Paulo customer destinations  
**Period:** June versus August 2018  
**Metric:** late rate, median promised window, median fulfillment time  
**Comparison:** same geography before and after promise tightening

Marketplace August late rate: 393 / 6,351 = 6.19%. Median purchase-to-delivery fell from 6.5 days in June to 5.6 days in August, while the median promised window fell from 28 days to 14 days.

São Paulo:

```text
June 2018:   20 / 2,735 = 0.73% late; median promise 22 days; median fulfillment 5.9 days
August 2018: 285 / 3,164 = 9.01% late; median promise 10 days; median fulfillment 5.7 days
```

São Paulo accounted for 285 of 393 August late orders (72.5%). Excluding the top 1% of transit times barely changes August (6.19% → 6.16%).

This is a different failure mode from the earlier transit spikes. A seller-level July–August late-rate increase is therefore a monitoring signal, not evidence of seller-handling failure.

**Source:** `docs/root_cause_analysis.md`; `outputs/analysis/group_comparisons.csv`


### Finding 4 — Late delivery is strongly associated with negative reviews

**Population:** delivery-performance-eligible orders with a usable review (94,774)  
**Period:** full extract; comparable-window sensitivity leaves the result unchanged  
**Metric:** negative-review rate (score ≤ 2)  
**Comparison:** late versus early delivery

```text
Early: 7,945 / 87,203 =  9.11%  (95% CI 8.92%–9.30%)
Late:  3,932 /  6,307 = 62.34%  (95% CI 61.14%–63.53%)
Difference: 53.23 pp           (95% CI 52.02–54.44)
```

A 1–3 day delay is already large: 31.97% versus 9.11% (22.86 pp; 95% CI 20.72–25.00). After adjustment for GMV band, customer-state group, repeat purchase, and multi-seller structure, a 1–3 day delay has 4.92× the odds of a negative review versus early delivery (95% CI 4.45–5.45).

The association is not perfectly monotonic: 15–30 days late is 81.72% negative; 31+ days is 68.01%. Excluding 31+ day delays leaves a 52.93 pp gap.

Review missingness is informative. Unreviewed eligible orders are more often late (13.38% versus 6.65%; +6.73 pp, 95% CI 5.10–8.36). Observed reviews therefore underrepresent some late experiences.

**Source:** `docs/customer_experience_analysis.md`; `docs/statistical_validation.md`; `outputs/analysis/review_effect_estimates.csv`; `outputs/analysis/review_outcome_model.csv`


### Finding 5 — Late seller-orders are concentrated; the watchlist is an investigation queue

**Population:** certified seller-orders (97,811 eligible; 6,547 late; late rate 6.69%, 95% CI 6.54%–6.85%)  
**Period:** full certified seller extract; recent-change flags use July–August 2018  
**Metric:** late seller-orders, excess late, and pooled late rate  
**Comparison:** marketplace seller-order benchmark and other sellers

```text
98 sellers account for 50% of late seller-orders
398 sellers account for 80%
25-seller watchlist: 1,408 late seller-orders = 21.5% of marketplace late units
Watchlist pooled late rate: 1,408 / 15,359 = 9.17% (95% CI 8.72%–9.63%)
Versus other sellers: +2.93 pp (95% CI 2.45–3.42)
```

Rate and contribution are kept separate. Excess late = observed late − (eligible × 6.69%). A 100 eligible seller-order screen leaves 210 sellers and about 61% of late units.

The high-excess core (14 sellers with ≥100 eligible and ≥15 excess late) is the first investigation set. Recent-deterioration sellers can have lifetime intervals that overlap or fall below the marketplace rate. They stay on the list as a monitoring queue, not as a penalty ranking.

**Source:** `docs/seller_concentration.md`; `analysis.seller_watchlist`; `outputs/analysis/group_comparisons.csv`


## 3. Connecting the main deterioration to marketplace impact

The February–March 2018 chain is supported end to end:

```text
Late-rate spike
  2,254 / 13,558 = 16.62%  (+13.11 pp vs early-2017 baseline)
        ↓
Longer carrier transit
  median ~10–11 days in Feb–Mar vs ~7 days earlier;
  late-order median transit 26.2 days vs 6.9 days early
        ↓
Geographic concentration
  Rio de Janeiro 34% late; 597 / 2,254 = 26.5% of those late orders
        ↓
Customer-experience association
  late reviewed orders: 62.34% negative vs 9.11% early
        ↓
Marketplace scale
  R$314,172 late GMV in two months;
  comparable-window late GMV R$982,503
```

Seller concentration still matters for investigation, but the evidence does **not** support treating seller handling as the primary driver of this episode. Category mix also does not explain it.

The August 2018 chain is different and should not be forced into the transit story:

```text
Fulfillment stayed fast
        ↓
Promised windows tightened (28 → 14 days; SP 22 → 10 days)
        ↓
São Paulo 285 / 393 August late orders
        ↓
Late orders still have the same review association, but the operational lever is promise setting
```


## 4. Seller and segment priorities

Investigate in this order. Rate alone does not determine priority.

### First: high-excess sellers

Sellers with at least 100 eligible seller-orders and at least 15 excess late seller-orders.

| Seller | Eligible | Late | Rate | Excess | Seller-item GMV |
| ------ | -------: | ---: | ---: | -----: | --------------: |
| `4a3ca931…` | 1,772 | 172 | 9.71% | +53.4 | R$200,473 |
| `06a2c3af…` | 389 | 74 | 19.02% | +48.0 | R$36,409 |
| `4869f7a5…` | 1,124 | 118 | 10.50% | +42.8 | R$229,473 |
| `1f50f920…` | 1,399 | 124 | 8.86% | +30.4 | R$106,939 |
| `7d13fca1…` | 558 | 64 | 11.47% | +26.7 | R$113,629 |
| `81602554…` | 380 | 52 | 13.68% | +26.6 | R$47,018 |
| `88460e8e…` | 246 | 42 | 17.07% | +25.5 | R$31,547 |

These combine volume, rate above the 6.69% benchmark, and commercial exposure.

One mix caveat: `7c67e144…` (office furniture) has marketplace excess +23.9 but category-adjusted excess +10.8. Investigate with category context, not as a pure seller-handling case.

### Second: Rio de Janeiro destinations during peak periods

This is a geography segment, not a seller list. During the largest spike it combined a 34% late rate with 26.5% of late units. Transit, not seller state, is the associated component.

### Third: São Paulo promise-setting after compression

This is a process/geography segment. It dominates August late volume while fulfillment remains fast.

### Monitor, do not escalate first: recent-deterioration-only sellers

Eleven watchlist sellers enter only through July–August change. Examples such as `da8622b1…`, `d91fb3b7…`, and `f8db351d8…` have lifetime excess near zero or negative. Their August movement is consistent with marketplace promise compression. Keep them on a monitoring list.

Do not prioritize one-order 100% late-rate sellers. They fail the volume screen and contribute almost no marketplace late units.


## 5. Intervention framework

These are investigation and monitoring actions. They are not estimated treatment effects.

### Recommendation A — Investigate transit performance for long-delay destinations

| Item | Definition |
| ---- | ---------- |
| **Owner** | Fulfillment Operations, with Marketplace Operations |
| **Target** | Carrier transit to high-delay customer states, starting with Rio de Janeiro, during peak-volume months |
| **Action** | Reconstruct handoff-to-delivery times for February–March-like periods; separate seller handling from transit; identify whether delay concentrates after carrier handoff |
| **Evidence** | Feb–Mar late rate 16.62% (+13.11 pp, 95% CI 12.44–13.78); late vs early median transit 26.2 vs 6.9 days; RJ 34% late and 26.5% of Feb–Mar late orders |
| **Success metric** | Comparable-window late rate; Rio de Janeiro late rate; median and p90 carrier transit among eligible orders |
| **Proposed monitoring rule** | Monthly late rate versus the 3.52% early-2017 baseline and the 6.82% window average. Investigate if a comparable month exceeds the window rate by more than the November gap’s lower bound (~8 pp) or if RJ monthly late rate returns above 20% with at least 500 eligible orders |

### Recommendation B — Review promised delivery windows after compression

| Item | Definition |
| ---- | ---------- |
| **Owner** | Marketplace Operations |
| **Target** | Promise-setting for high-volume destinations, starting with São Paulo |
| **Action** | Compare promised window versus realized purchase-to-delivery time. Determine whether August-like late-rate increases occur while fulfillment stays fast |
| **Evidence** | August 6.19% (+2.67 pp vs baseline); median promise 28 → 14 days while fulfillment got faster; SP 285 / 393 August late orders; SP median promise 22 → 10 days with fulfillment ~5.7–5.9 days |
| **Success metric** | Monthly median promised window; late rate in months when fulfillment is stable or faster |
| **Proposed monitoring rule** | If median promised window falls sharply while median fulfillment does not worsen, treat a late-rate rise as a promise-setting signal, not a transit signal. Do not add those sellers to a handling escalation solely from a July–August rate change |

### Recommendation C — Investigate the high-excess seller queue

| Item | Definition |
| ---- | ---------- |
| **Owner** | Seller Success, with Fulfillment Operations |
| **Target** | The 14 high-excess sellers; start with the seven listed above |
| **Action** | For each seller, inspect handling time, destination mix, category mix, and whether late orders are also negative-review orders. Use excess late and contribution, not late rate alone |
| **Evidence** | 14 sellers meet ≥100 eligible and ≥15 excess late; the seven largest combine +25 to +53 excess late and 21.5% watchlist coverage at the 25-seller level; watchlist pooled late rate 9.17% vs 6.23% for other sellers (+2.93 pp, 95% CI 2.45–3.42) |
| **Success metric** | Seller excess late; seller-order late rate versus the 6.69% marketplace benchmark; late seller-order count |
| **Proposed monitoring rule** | Recalculate excess late monthly at the seller-order grain. Keep the 100-order volume screen and use excess late plus contribution to determine whether a seller remains in the investigation queue. Recent-deterioration-only sellers stay on a separate monitor |

### Recommendation D — Track delivery reliability as the customer-experience outcome

| Item | Definition |
| ---- | ---------- |
| **Owner** | Marketplace Operations |
| **Target** | Marketplace reviewed eligible orders; do not use reviews to penalize individual sellers |
| **Action** | Report negative-review rates by delivery class and delay band alongside late rate. Keep missing reviews visible |
| **Evidence** | Late vs early gap 53.23 pp (52.02–54.44); 1–3 day delay still +22.86 pp; adjusted OR 4.92 (4.45–5.45) for 1–3 days late versus early; unreviewed orders more often late |
| **Success metric** | Late-versus-early negative-review gap; late-order negative-review rate; delivered review coverage |
| **Proposed monitoring rule** | If the late-versus-early gap stays near 50 pp, delivery reliability remains the CX lever. Do not interpret a change in the gap as the causal effect of an intervention |


## 6. Success metrics

Use existing certified metrics. Do not create a composite score.

| Priority | Primary metric | Grain | Comparison |
| -------- | -------------- | ----- | ---------- |
| Marketplace reliability | Late delivery rate | Order, comparable month | 3.52% early-2017 baseline; 6.82% window average |
| Transit-driven spikes | Median / p90 carrier transit | Eligible orders | Late vs early; peak months vs early-2017 |
| Promise compression | Median promised window | Delivered orders | Adjacent months with stable fulfillment |
| Destination risk | Customer-state late rate | Order | RJ vs marketplace; volume shown with the rate |
| Seller investigation | Excess late seller-orders | Seller-order | Marketplace expected late = eligible × 6.69% |
| Customer experience | Negative-review rate by delivery class | Reviewed eligible orders | Late vs early; keep missing reviews separate |

A successful operations program would show fewer late orders in transit-spike conditions, more stable promises when fulfillment is already fast, and declining excess late among the high-excess sellers. The data do not estimate how large those improvements would be.


## 7. Limitations

* The analysis is observational. It does not estimate the causal effect of faster transit, looser promises, or seller coaching.
* Reviews are missing more often on late and repeat orders. The review model is estimated on a slightly more on-time sample.
* Reviews are order-level, including multi-seller orders. They should not be used as a seller penalty.
* There is no true carrier identifier or carrier-level SLA. Transit is inferred from timestamps.
* Seller handling timestamps are order-level events and are not seller-specific clocks on multi-seller orders.
* First-observed seller activity is not a verified onboarding date.
* The extract ends in August 2018, with sparse tails. August promise compression has no later confirmation month.
* No certified SLA tier exists. Promise dates are the available customer commitment.
* Excess late is a benchmark residual, not a causal seller effect.
* Destination-adjusted seller expectations reuse marketplace geography rates and do not isolate seller behavior.
* Orders share sellers, destinations, and calendar periods, so conventional confidence intervals may understate some dependence in the data.


## 8. Traceability

| Number | Origin |
| ------ | ------ |
| 6,509 / 95,453 = 6.82% | `metrics.kpi_orders`, comparable eligible; `docs/root_cause_analysis.md` |
| 6,547 / 97,811 = 6.69% | `metrics.kpi_seller_orders`; `docs/seller_concentration.md` |
| Episode late rates and CIs | `outputs/analysis/group_comparisons.csv` |
| Transit / handling / promise medians | `docs/root_cause_analysis.md`; `analysis.fulfillment_decomposition` |
| RJ and SP splits | `docs/root_cause_analysis.md`; `analysis.segment_fulfillment_month` |
| 62.34% vs 9.11%; 53.23 pp | `analysis.delivery_class_review_rates`; `outputs/analysis/review_effect_estimates.csv` |
| OR 4.92 for 1–3 days late vs early | `outputs/analysis/review_outcome_model.csv` |
| Watchlist 25 / 1,408 / 21.5% | `analysis.seller_watchlist`; `docs/seller_concentration.md` |
| High-excess table | `analysis.seller_watchlist` where `is_high_excess` |

Reproduction of the underlying analyses:

```text
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_fulfillment_root_cause
python -m python.scripts.run_seller_concentration
python -m python.scripts.run_customer_experience
python -m python.scripts.run_statistical_validation
pytest tests/test_fulfillment_root_cause.py tests/test_seller_concentration.py tests/test_customer_experience.py tests/test_statistical_validation.py -q
```
