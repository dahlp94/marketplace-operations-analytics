# Seller Concentration and Prioritization

## Objective

Identify which sellers deserve operational investigation first by separating:

* **failure rate** — how often a seller's eligible orders are late;
* **marketplace contribution** — how much that seller contributes to all late seller-orders;
* **excess late orders** — how many more late seller-orders occurred than expected at the marketplace benchmark.

The output is a transparent **candidate watchlist**, not a causal attribution or intervention ranking.

All base counts, rates, contributions, and merchandise values come from the certified seller KPI layer.


## Seller Grain

Seller performance is measured at the certified seller-order grain:

```text id="3g4vrk"
seller-order = distinct (seller_id, order_id)
```

The full certified extract contains:

* **97,811 eligible seller-orders**
* **6,547 late seller-orders**
* **6.69% marketplace seller-order late rate**
* **3,095 sellers**
* **1,274 sellers with at least one late seller-order**

There are slightly more late seller-orders than late marketplace orders because a multi-seller order can contribute one seller-order to each participating seller.

Seller GMV uses only the value of that seller's items. Whole-order GMV is not duplicated across sellers.


# 1. Late Deliveries Are Concentrated

Late seller-orders are distributed across many sellers, but the impact is concentrated.

| Marketplace late-unit share | Sellers required |
| --------------------------- | ---------------: |
| 50%                         |               98 |
| 80%                         |              398 |

This means roughly **8% of sellers with late orders account for half of all marketplace late seller-orders**.

The largest contributor has:

```text id="2g8b87"
172 late / 1,772 eligible = 9.71%
```

and contributes **2.63%** of all late seller-orders.

This concentration makes seller prioritization operationally useful.


# 2. Late Rate Alone Is Misleading

A seller with one late order out of one eligible order has a 100% late rate, but almost no marketplace impact.

Conversely, a large seller can generate many late orders while still performing better than the marketplace average.

For example:

```text id="9yvp42"
seller 6560211a...

96 late / 1,819 eligible = 5.28%
marketplace rate = 6.69%
```

This seller ranks highly by late-unit count because of volume, but its failure rate is actually **below the marketplace benchmark**.

Rate and contribution therefore answer different questions and should not be used interchangeably.


# 3. Excess Late Orders Combine Rate and Scale

The primary benchmark is the certified marketplace seller-order late rate:

```text id="ys4ds5"
6,547 / 97,811 = 6.6935%
```

For each seller:

```text id="2xntnj"
expected late =
eligible seller-orders × marketplace late rate

excess late =
observed late seller-orders − expected late
```

A positive excess means the seller generated more late seller-orders than expected if it had performed at the marketplace rate.

### Example: above benchmark

```text id="pt18o0"
seller 4a3ca931...

Eligible = 1,772
Observed late = 172
Expected late = 118.61
Excess late = +53.39
Late rate = 9.71%
```

### Example: below benchmark

```text id="8xx1o0"
seller 6560211a...

Eligible = 1,819
Observed late = 96
Expected late = 121.76
Excess late = -25.76
Late rate = 5.28%
```

Both sellers generate many late orders, but only the first materially exceeds marketplace expectations.

This is why excess late orders are more useful for prioritization than raw late counts alone.


# 4. Benchmark Choice Is Reasonably Stable

The marketplace rate is the primary benchmark because it is simple, transparent, and uses the same grain as seller contribution.

Alternative comparisons were also examined using:

* primary product category;
* customer-destination mix;
* seller state;
* comparable-window marketplace performance.

Among sellers with meaningful volume, these alternatives generally preserve the same high-excess pattern.

One example where mix matters is an office-furniture seller with:

```text id="4z1m37"
Marketplace excess: +23.9
Category-adjusted excess: +10.8
```

This indicates that some of its apparent excess is associated with operating in a higher-late-rate category.

The alternatives are therefore useful as sensitivity checks, but the marketplace benchmark remains suitable for the primary prioritization view.


# 5. Minimum Volume Creates a Trade-Off

Very small sellers create noisy rate estimates, so prioritization is evaluated across several minimum-volume thresholds.

| Minimum eligible orders | Sellers remaining | Late units retained | Marketplace coverage |
| ----------------------: | ----------------: | ------------------: | -------------------: |
|                       1 |             2,970 |               6,547 |                 100% |
|                      10 |             1,237 |               6,145 |                  94% |
|                      30 |               627 |               5,485 |                  84% |
|                      50 |               425 |               4,982 |                  76% |
|                     100 |               210 |               3,986 |                  61% |
|                     200 |                86 |               2,946 |                  45% |
|                     300 |                56 |               2,468 |                  38% |

A threshold of **100 eligible seller-orders** leaves only **210 sellers** to review while preserving about **61% of all marketplace late seller-orders**.

That provides a reasonable balance between analytical stability and operational workload.


# 6. Candidate Watchlist

The watchlist uses explicit rules rather than a composite score.

A seller enters if it meets at least one of these conditions:

### High excess

* eligible seller-orders ≥ 100;
* excess late seller-orders ≥ 15.

### High rate and high volume

* eligible seller-orders ≥ 100;
* late rate at least 3 percentage points above marketplace;
* at least 30 late seller-orders.

### Recent deterioration

* August eligible volume ≥ 30;
* July-to-August late-rate increase ≥ 5 percentage points.

The resulting watchlist contains:

```text id="zirq6a"
25 sellers
1,408 late seller-orders
21.5% of marketplace late seller-orders
```

Within the watchlist:

* **14** sellers meet the high-excess rule;
* **11** meet the high-rate/high-volume rule;
* **11** show recent deterioration.

Sellers can satisfy more than one condition.


## High-Excess Core

The most operationally important portion of the watchlist is the high-excess group.

| Seller      | Eligible | Late |   Rate | Expected | Excess |
| ----------- | -------: | ---: | -----: | -------: | -----: |
| `4a3ca931…` |    1,772 |  172 |  9.71% |    118.6 |  +53.4 |
| `06a2c3af…` |      389 |   74 | 19.02% |     26.0 |  +48.0 |
| `4869f7a5…` |    1,124 |  118 | 10.50% |     75.2 |  +42.8 |
| `1f50f920…` |    1,399 |  124 |  8.86% |     93.6 |  +30.4 |
| `7d13fca1…` |      558 |   64 | 11.47% |     37.3 |  +26.7 |
| `81602554…` |      380 |   52 | 13.68% |     25.4 |  +26.6 |
| `88460e8e…` |      246 |   42 | 17.07% |     16.5 |  +25.5 |

These sellers combine meaningful volume with substantially more late seller-orders than expected.

They are natural candidates for further investigation.


# 7. Recent Deterioration Requires Caution

Recent deterioration is treated separately from persistent poor performance.

Some July-to-August deteriorating sellers have negative lifetime excess late orders.

Stage 1 also showed that August 2018 marketplace deterioration was associated with tighter promised delivery windows, particularly in São Paulo.

A recent seller-level increase therefore does **not** automatically imply a seller-handling problem.

It is a monitoring signal, not evidence of cause.


# Key Findings

1. **Seller late-delivery impact is meaningfully concentrated.**
   Only 98 sellers account for half of marketplace late seller-orders.

2. **Late rate and business impact are different.**
   High percentages among low-volume sellers are common and should not drive prioritization alone.

3. **Excess late orders provide a simple rate-and-scale measure.**
   They identify sellers generating more late seller-orders than expected at the marketplace benchmark.

4. **A 100-order volume threshold provides a reasonable operational screen.**
   It reduces the review population to 210 sellers while retaining about 61% of late units.

5. **The final 25-seller watchlist is intentionally narrow and explainable.**
   It captures 21.5% of marketplace late seller-orders using explicit rules rather than an opaque score.


# Operational Interpretation

The seller analysis supports a two-step workflow:

```text id="ds4krl"
Marketplace problem
        ↓
Identify sellers contributing disproportionate late volume
        ↓
Investigate those sellers using operational and customer-experience context
```

The watchlist should therefore be treated as an **investigation queue**.

It does not determine:

* whether a seller caused a late delivery;
* whether the carrier was responsible;
* whether the customer promise was unrealistic;
* which seller should receive an intervention first.

Those questions require customer-experience and statistical analysis.


# Limitations

* Excess late orders are benchmark comparisons, not causal residuals.
* Seller fulfillment timestamps come from order-level events and are not seller-specific clocks on multi-seller orders.
* Primary category is a convenience label; sellers may operate across multiple categories.
* Destination-adjusted expectations reuse marketplace geography rates and do not isolate seller behavior.
* July-to-August deterioration is based on a short time window.
* Review outcomes remain order-level customer-experience measures associated with participating sellers.
* No certified SLA tier is available.


# Reproduction

```bash id="mvp24s"
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_seller_concentration
python -m python.scripts.run_analysis_validation
pytest tests/test_seller_concentration.py -q
```

Primary artifacts:

```text id="z3i30x"
sql/analysis/seller_concentration.sql
python/scripts/seller_concentration.py
python/scripts/run_seller_concentration.py
python/notebooks/seller_concentration_analysis.ipynb

outputs/analysis/seller_prioritization.csv
outputs/analysis/seller_watchlist.csv
outputs/analysis/seller_volume_threshold_sensitivity.csv

outputs/figures/seller_pareto.png
outputs/figures/seller_rate_vs_volume.png
outputs/figures/seller_excess_late.png
```
