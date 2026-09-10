# Fulfillment Root-Cause Analysis

## Objective

Determine which operational factors are most associated with late marketplace deliveries and identify where deterioration is concentrated.

The analysis focuses on three fulfillment components:

* **Seller handling:** approval to carrier handoff
* **Carrier transit:** carrier handoff to customer delivery
* **Promise performance:** actual delivery relative to the estimated delivery date

All metrics use the certified KPI layer. Results are observational and should not be interpreted as causal effects.


## Analysis Window

The comparable analysis period is:

```text
2017-02-01 through 2018-08-31
```

This includes:

* **19 complete months**
* **95,453 delivery-performance-eligible orders**
* **6,509 late orders**
* **6.82% overall late-delivery rate**
* **R$982,502.52 late merchandise value**

Incomplete boundary periods remain available in the data but are excluded from deterioration comparisons.


# 1. Delivery Performance Deteriorated in Distinct Episodes

Late deliveries were not distributed uniformly over time.

The early comparable period, February through August 2017, provides a useful baseline:

```text
747 late / 21,247 eligible = 3.52%
```

Three later periods stand out.

### November 2017

```text
904 late / 7,288 eligible = 12.40%
Late GMV = R$126,218
```

This represents an increase of **8.88 percentage points** from the early baseline.

The deterioration was concentrated around late November:

```text
Week of Nov 20: 503 / 2,915 = 17.26%
Week of Nov 27: 298 / 2,046 = 14.57%
```

Both seller handling and carrier transit increased during this period.


### February–March 2018

This was the largest deterioration episode.

```text
February: 926 / 6,555 = 14.13%
March:  1,328 / 7,003 = 18.96%

Combined:
2,254 / 13,558 = 16.62%
Late GMV = R$314,172
```

The weekly late-delivery rate reached **26.34%** during the week beginning February 26 and remained elevated for several weeks.

This was not a single-week anomaly.


### August 2018

August shows a different pattern:

```text
393 / 6,351 = 6.19%
```

Unlike the earlier spikes, fulfillment itself was becoming faster.

```text
Median purchase-to-delivery:
June = 6.5 days
August = 5.6 days

Median promised window:
June = 28 days
August = 14 days
```

This suggests that August deterioration was associated more with **tighter delivery promises** than slower fulfillment.


# 2. Carrier Transit Is the Strongest Fulfillment Signal

Late orders have substantially longer carrier transit than orders delivered on time or early.

### Comparable-window medians

| Delivery outcome | Seller handling | Carrier transit | Promised window |
| ---------------- | --------------: | --------------: | --------------: |
| Early            |       1.78 days |       6.93 days |         24 days |
| On time          |       2.78 days |      15.19 days |         20 days |
| Late             |       3.07 days |      26.17 days |         23 days |

The largest separation occurs in **carrier transit**.

Late orders have a median transit time approximately **19 days longer** than early orders.

Seller handling is also higher among late orders, but the difference is much smaller.


## February–March 2018

Carrier transit deteriorated sharply:

```text
Median carrier transit
February: 11.02 days
March:     9.88 days

Typical early-period level:
~7 days
```

The upper tail also deteriorated:

```text
90th percentile transit
February: 26.8 days
March:    28.2 days
```

Seller handling increased only modestly during the same period.

This makes carrier transit the component most strongly associated with the largest marketplace deterioration episode.


# 3. Seller Handling Matters, but Appears Secondary

Across the comparable period:

```text
Late orders:
mean handling   = 5.54 days
median handling = 3.07 days

Not-late orders:
mean handling   = 2.62 days
median handling = 1.79 days
```

Handling therefore differs meaningfully between late and non-late orders.

However, seller handling does not track the major February–March deterioration as strongly as carrier transit.

The evidence supports treating seller handling as a **secondary operational contributor**, not the dominant marketplace signal.


# 4. Promise Setting Explains a Different Type of Failure

Across the full comparable period, late and non-late orders were generally given similar promised windows.

That makes promise-setting a weak explanation for the typical late order.

August 2018 is different.

In São Paulo:

```text
June 2018
20 late / 2,735 eligible = 0.73%
Median promised window = 22 days
Median fulfillment      = 5.9 days

August 2018
285 late / 3,164 eligible = 9.01%
Median promised window = 10 days
Median fulfillment      = 5.7 days
```

Fulfillment remained almost unchanged while the promised window became much tighter.

This pattern is consistent with **promise compression rather than fulfillment deterioration**.


# 5. Geography Shows Strong Concentration

Customer geography provides a clearer signal than seller geography.

## Rio de Janeiro

Across the full comparable analysis:

```text
1,495 late / 12,350 eligible = 12.11%
```

During major deterioration periods:

```text
November 2017: 263 / 1,012 = 25.99%
February 2018: 299 /   879 = 34.02%
March 2018:    298 /   864 = 34.49%
```

Rio de Janeiro contributed:

```text
597 of 2,254 late orders
```

during February–March 2018, approximately **26.5%** of all late orders in those two months.

Transit times in Rio were also substantially elevated.


## São Paulo

São Paulo produced the most late orders overall because it has much greater order volume:

```text
1,820 late / 40,494 eligible = 4.49%
```

Its February–March late rates remained considerably below Rio de Janeiro.

However, São Paulo dominates the August 2018 promise-compression episode:

```text
285 of 393 August late orders = 72.5%
```

This demonstrates why **rate and contribution must be analyzed separately**.


# 6. Category Mix Is Not the Main Explanation

The highest-volume categories naturally generate many late orders:

```text
bed_bath_table:
694 / 9,481 = 7.32%

health_beauty:
649 / 8,674 = 7.48%

sports_leisure:
495 / 7,581 = 6.53%
```

Their late rates are relatively similar.

The evidence therefore does not suggest that one product category explains the major marketplace deterioration episodes.

Category-level GMV is allocated using item-level value, preventing multi-category seller-orders from duplicating merchandise value.

Low-volume categories remain flagged rather than treated as directly comparable with large categories.


# 7. Seller Cohorts Provide a Weaker Signal

Sellers first observed from mid-2017 through early 2018 generally show late rates around **8–9%**, compared with approximately **6.0–6.6%** for earlier high-volume cohorts.

The difference exists, but it is weaker than the time and customer-geography patterns.

The cohort variable represents **first observed marketplace activity**, not verified seller onboarding.

It should therefore be interpreted cautiously.


# 8. Extreme Delays Do Not Explain the Entire Pattern

Extreme delivery delays exist.

The largest comparable delay was:

```text
188 days late
Seller handling = 3.15 days
Carrier transit = 205.19 days
```

The other largest delays are also dominated by long transit times.

Removing the top 1% of transit observations changes the marketplace late rate from:

```text
6.82% → 5.89%
```

but the major deterioration periods remain:

| Period   | Original | Excluding top 1% transit |
| -------- | -------: | -----------------------: |
| Nov 2017 |   12.40% |                   11.12% |
| Feb 2018 |   14.13% |                   11.58% |
| Mar 2018 |   18.96% |                   16.61% |
| Aug 2018 |    6.19% |                    6.16% |

The February–March pattern therefore cannot be explained solely by a few extreme shipments.

August is almost unchanged by the sensitivity test, further supporting the interpretation that its pattern differs from the earlier transit-driven episodes.


# Key Findings

### 1. Carrier transit is the strongest operational signal

The largest deterioration periods coincide with substantial increases in carrier transit time.

Late orders have a median carrier transit of **26.17 days**, compared with approximately **6.93 days for early orders**.


### 2. Seller handling contributes, but appears secondary

Seller handling is higher for late orders and increased during some deterioration periods, particularly November 2017.

However, its movements are smaller than those observed in carrier transit.


### 3. Customer geography materially concentrates marketplace risk

Rio de Janeiro combines high late-delivery rates with substantial volume during the February–March 2018 deterioration.

São Paulo contributes many late orders because of scale but generally has a lower failure rate.


### 4. August 2018 represents a different operational pattern

Fulfillment remained fast while promised delivery windows became substantially shorter.

The evidence is more consistent with **promise compression** than a deterioration in physical fulfillment.


### 5. Extreme delays amplify the problem but do not create it

Removing the most extreme transit observations reduces late rates but leaves the main deterioration episodes clearly visible.


# Operational Interpretation

The marketplace does not appear to have one universal late-delivery problem.

Instead, the evidence suggests at least two distinct patterns:

### Fulfillment deterioration

Most visible in:

* November 2017
* February–March 2018

and primarily associated with **longer carrier transit**, with seller handling playing a secondary role.

### Promise compression

Most visible in:

* August 2018
* particularly São Paulo

where fulfillment remained relatively fast but customers were given substantially tighter delivery windows.

These patterns should not be managed identically.

The next analysis should determine which sellers contribute the greatest operational impact once **failure rate, volume, marketplace contribution, and excess late orders** are considered together.


# Limitations

* This is observational analysis and does not establish causality.
* Seller handling and carrier transit are based on order-level timestamps. Multi-seller orders do not contain seller-specific fulfillment clocks.
* Product-category units can include the same seller-order in multiple categories, although merchandise value is allocated at the underlying item/category grain.
* Seller cohort represents first observed activity, not verified onboarding.
* Low-volume segments are retained but flagged.
* The comparable analysis ends in August 2018, so later recovery cannot be observed.
* Statistical inference and regression are intentionally deferred to later analysis.


# Reproduction

```bash
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_fulfillment_root_cause
python -m python.scripts.run_analysis_validation
pytest tests/test_fulfillment_root_cause.py -q
```

Primary analytical artifacts:

```text
sql/analysis/fulfillment_root_cause.sql
python/scripts/fulfillment_root_cause.py
python/scripts/run_fulfillment_root_cause.py
python/notebooks/fulfillment_root_cause_analysis.ipynb
outputs/analysis/fulfillment_trends.csv
outputs/analysis/fulfillment_decomposition.csv
outputs/analysis/segment_delivery_performance.csv
```

Seller-level concentration, excess late orders, and the candidate watchlist are documented in [`docs/seller_concentration.md`](seller_concentration.md).
