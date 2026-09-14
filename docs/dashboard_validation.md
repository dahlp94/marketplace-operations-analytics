# Dashboard Validation

Reconcile Tableau to certified SQL before treating the workbook as finished.

Period rates must use:

```text
SUM(late) / SUM(eligible)
````

not the average of monthly rates.

If Tableau and SQL agree but both disagree with a finding document, treat that as an upstream documentation issue.

Rebuild and validate the dashboard layer with:

```bash
python -m python.scripts.build_dashboard_layer
python -m python.scripts.export_dashboard_extracts
pytest tests/test_dashboard_layer.py -q
```

Current dashboard-layer validation:

```text
8 passed
```


# Critical cases

| Case                    | Source                                                  | Target                                                                                                                               |
| ----------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Executive full extract  | `executive_overview`                                    | 99,441 orders; 96,470 eligible; 89,936 on-time; 6,534 late; GMV 13,591,643.70; late GMV 985,924.34; 14,197 / 97,530 negative reviews |
| Comparable late rate    | `executive_overview`                                    | 6,509 / 95,453 = 6.82%; late GMV 982,502.52                                                                                          |
| February–March 2018     | `fulfillment_trends`                                    | 2,254 / 13,558 = 16.62% (926 + 1,328 late)                                                                                           |
| August 2018             | `fulfillment_trends`                                    | 393 / 6,351 = 6.19%; median promised window 14 days                                                                                  |
| High-excess seller      | `seller_performance` `4a3ca9315b744ce9f8e9374361493884` | 1,772 eligible; 172 late; 9.71%; excess +53.4; on watchlist; high-excess                                                             |
| Watchlist               | `seller_performance` where `is_on_watchlist`            | 25 sellers; 1,408 late seller-orders; 14 high-excess                                                                                 |
| Rio February 2018       | `geography_month`                                       | 299 / 879 = 34.02%                                                                                                                   |
| São Paulo August 2018   | `geography_month`                                       | 285 / 3,164 = 9.01%; 285 of 393 August late orders                                                                                   |
| Category non-additivity | `category_performance` full extract                     | GMV sums to marketplace GMV; late units ≠ 6,547                                                                                      |
| Rolling 30/90           | `marketplace_rolling`                                   | Latest full comparable date 2018-08-31; 364 / 6,045 and 669 / 18,278                                                                 |
| Early vs late reviews   | `delivery_review`                                       | 9.11% vs 62.34%                                                                                                                      |
| Refresh                 | rebuild + CSV replace                                   | Headline cases above still match; no manual extract edits                                                                            |

Comparable-window Rio snapshot is:

```text
1,492 / 12,219 = 12.21%
```

from `analysis.segment_fulfillment_performance`.

Use that certified SQL row, not older narrative totals.


# Tableau page validation

## Page 1 — Executive Overview

**Status: PASS / FROZEN**

The Executive Overview was reconciled against the certified dashboard extracts and approved for portfolio use.

The page answers:

* What is current marketplace performance?
* Is delivery performance improving or deteriorating?
* How large is the late-delivery problem?
* What operational areas should be investigated first?

### Comparable-window KPI validation

| Metric                   | Tableau value |
| ------------------------ | ------------: |
| Orders                   |        98,292 |
| Delivery-eligible orders |        95,453 |
| On-time orders           |        88,944 |
| On-time delivery rate    |        93.18% |
| Late orders              |         6,509 |
| Late delivery rate       |         6.82% |
| GMV                      |  R$13,421,400 |
| Late GMV                 |  R$982,502.52 |
| Negative reviews         |        13,979 |
| Reviewed orders          |        96,445 |
| Negative review rate     |        14.49% |

The Executive page defaults to:

```text
reporting_scope = comparable_trend_window
```

rather than the full extract.

This prevents the comparable-window late count of **6,509** from being replaced with the full-extract count of **6,534**.

### Trend validation

The monthly delivery-performance chart uses:

```text
fulfillment_trends
```

restricted to:

```text
is_comparable_trend_window = True
```

Validated episode spot checks:

| Period        |  Late | Eligible | Late rate |
| ------------- | ----: | -------: | --------: |
| November 2017 |   904 |    7,288 |    12.40% |
| February 2018 |   926 |    6,555 |    14.13% |
| March 2018    | 1,328 |    7,003 |    18.96% |
| August 2018   |   393 |    6,351 |     6.19% |

Reference lines:

```text
Early-2017 baseline:       3.52%
Comparable-window average: 6.82%
```

The dashboard does not average monthly late rates to produce the period rate.

The comparable-window rate remains:

```text
6,509 / 95,453 = 6.82%
```

### Operational signals

The Executive page summarizes four validated investigation signals.

#### Transit deterioration

```text
November 2017:     12.40% late
February–March:    16.62% late
March peak:        18.96% late
```

The earlier deterioration is associated primarily with longer carrier transit.

#### Promise compression

```text
August 2018 late rate: 6.19%
São Paulo late orders: 285 of 393 August late orders
```

This period differs from the earlier transit-associated spikes because promised delivery windows tightened while physical fulfillment remained relatively fast.

#### Customer experience

```text
Late negative review rate:  62.34%
Early negative review rate:  9.11%
```

These are observational associations, not causal effects.

#### Seller investigation queue

```text
25 sellers
1,408 late seller-orders
approximately 21.5% of marketplace late seller-orders
```

### High-excess seller preview

Representative seller:

```text
4a3ca9315b744ce9f8e9374361493884
```

Validated values:

| Metric                   | Tableau value |
| ------------------------ | ------------: |
| Eligible seller-orders   |         1,772 |
| Late seller-orders       |           172 |
| Seller late rate         |         9.71% |
| Marketplace contribution |         2.63% |
| Excess late              |         +53.4 |

The Executive preview shows only a small high-excess investigation set rather than the full seller-analysis table.

### Screenshot

```text
dashboard/screenshots/executive_overview.png
```

Page 1 should not be modified further unless a data, metric, interaction, or reconciliation defect is discovered.


## Page 2 — Root Cause

**Status: PASS / FROZEN**

The Root Cause page was reconciled against the certified fulfillment and customer-experience extracts and approved for portfolio use.

The page answers:

> Is late-delivery deterioration associated more strongly with seller handling, carrier transit, or promise setting?

Seller handling, carrier transit, and promised delivery windows remain separate operational concepts.

No composite fulfillment score is used.

### Comparable-window fulfillment components

Source:

```text
fulfillment_components
```

Filter:

```text
analysis_period = comparable_trend_window
```

Validated medians:

| Delivery class | Median seller handling | Median carrier transit | Median promised window |
| -------------- | ---------------------: | ---------------------: | ---------------------: |
| Early          |              1.78 days |              6.93 days |                24 days |
| On-time        |              2.78 days |             15.19 days |                20 days |
| Late           |              3.07 days |             26.17 days |                23 days |

Validated interpretation:

* **Carrier transit** shows the largest separation between early and late deliveries.
* **Seller handling** is elevated among late orders but the difference is substantially smaller.
* **Promised windows** are similar for the typical early and late order across the full comparable window.
* These descriptive relationships are not presented as causal effects.

### Seller handling trend

Source:

```text
fulfillment_trends
```

The handling trend shows moderate movement over the comparable period.

Handling increases around November 2017 but does not track the largest deterioration as strongly as carrier transit.

The dashboard therefore treats seller handling as a secondary operational signal rather than the primary marketplace explanation.

### Carrier transit trend

Median carrier transit rises materially during the major deterioration period.

Important validated values include:

```text
February 2018: approximately 11.0 days
March 2018:    approximately 9.9 days
```

Typical earlier-period values are approximately:

```text
~7 days
```

The carrier-transit trend aligns strongly with the major November 2017 and February–March 2018 late-delivery episodes.

### Promised-window trend

The promised-window trend remains broadly in the low-to-mid 20-day range through most of the comparable period before tightening sharply late in the extract.

Key comparison:

```text
June 2018:   approximately 28 days
August 2018: 14 days
```

This supports treating August 2018 as a different operational pattern from the earlier transit deterioration.

### Late rate versus carrier transit

The dashboard compares:

```text
Late Delivery Rate
Median Carrier Transit Days
```

using separate axes.

The axes are not synchronized because the measures use different units.

Validated episode values:

| Period                  |    Late-delivery result |
| ----------------------- | ----------------------: |
| November 2017           |    904 / 7,288 = 12.40% |
| February 2018           |    926 / 6,555 = 14.13% |
| March 2018              |  1,328 / 7,003 = 18.96% |
| February–March combined | 2,254 / 13,558 = 16.62% |

The visual is descriptive evidence that the largest late-rate deterioration coincides with elevated carrier transit.

It does not establish carrier transit as a causal treatment effect.

### Late rate versus promised window

The dashboard also compares:

```text
Late Delivery Rate
Median Promised Window Days
```

with separate axes.

The August 2018 reference point is:

```text
Late rate:             6.19%
Median promised window: 14 days
```

This visual communicates that August differs from the earlier deterioration periods because promised windows tightened while fulfillment remained relatively fast.

### Customer experience by delivery class

Source:

```text
delivery_review
```

Validated negative-review rates:

| Delivery class | Negative review rate |
| -------------- | -------------------: |
| Early          |                9.11% |
| On-time        |               12.26% |
| Late           |               62.34% |

The dashboard keeps reviewed-order volume available as denominator context.

### Customer experience by delay severity

Source:

```text
delay_band_reviews
```

Validated values:

| Delay band      | Negative review rate |
| --------------- | -------------------: |
| 15+ days early  |                8.92% |
| 8–14 days early |                8.82% |
| 4–7 days early  |                9.75% |
| 1–3 days early  |               11.05% |
| On-time         |               12.26% |
| 1–3 days late   |               31.97% |
| 4–7 days late   |               67.53% |
| 8–14 days late  |               80.29% |
| 15–30 days late |               81.72% |
| 31+ days late   |               68.01% |

The dashboard does not describe this relationship as perfectly monotonic because the 31+ day delay group has a lower observed negative-review rate than the 15–30 day group.

The broader conclusion remains that negative-review rates become much higher once orders are late.

### Root-cause interpretation

The page supports the following validated interpretation:

1. Carrier transit is the strongest fulfillment signal associated with the largest deterioration episodes.
2. Seller handling is elevated among late orders but appears secondary at marketplace scale.
3. The typical early and late order has a broadly similar promised window.
4. August 2018 represents a distinct promise-compression pattern.
5. Late delivery is strongly associated with worse customer review outcomes.

No regression coefficients, odds ratios, p-values, predictive models, or causal-effect claims are exposed on the dashboard.

### Screenshot

```text
dashboard/screenshots/root_cause.png
```

Page 2 should not be modified further unless a data, metric, interaction, or reconciliation defect is discovered.


## Page 3 — Seller Performance

**Status: PASS / FROZEN**

The Seller Performance page was reconciled against the certified seller-order metrics and approved for portfolio use.

The page is designed around the distinction:

> High seller failure rate is not the same as high marketplace impact.

Seller metrics remain at **seller-order grain** and are not mixed with marketplace order-grain metrics.

### Watchlist population

Default population:

```text
is_on_watchlist = True
```

Validated values:

| Metric                                     |     Validated value |
| ------------------------------------------ | ------------------: |
| Watchlist sellers                          |                  25 |
| High-excess sellers                        |                  14 |
| Watchlist late seller-orders               |               1,408 |
| Marketplace late seller-order contribution | approximately 21.5% |

The default page state contains the complete 25-seller watchlist.

The `Investigation Queue` filter can isolate:

```text
investigate_high_excess
monitor_recent_deterioration
review_high_rate_high_volume
```

No new Tableau watchlist definition or composite seller score is used.

### Volume versus late-rate scatter

Source:

```text
seller_performance
```

Validated visual contract:

```text
x = delivery-eligible seller-orders
y = seller late rate
size = late seller-orders
color = investigation queue
```

Marketplace reference:

```text
6,547 / 97,811 = 6.69%
```

The dashboard correctly uses the **6.69% seller-order benchmark**, not the **6.82% marketplace order-level late rate**.

This distinction is required because the two measures use different analytical grains.

The scatter communicates that:

* a seller can have a very high late rate but low marketplace impact because of low volume;
* a high-volume seller with a more moderate rate can contribute substantially more late seller-orders;
* rate, volume, contribution, and excess late must be evaluated together.

### Investigation table

The operational seller table includes:

* seller;
* eligible seller-orders;
* late seller-orders;
* late rate;
* marketplace contribution;
* excess late;
* late GMV;
* July late rate;
* August late rate;
* July-to-August percentage-point change.

Supporting fields such as:

```text
investigation_queue
watchlist_reasons
seller_state
primary_product_category
```

remain available as context without replacing the core rate-and-volume metrics.

The investigation table is ordered primarily by excess late.

### Representative seller validation

Representative seller:

```text
4a3ca9315b744ce9f8e9374361493884
```

Validated values:

| Metric                   |             Tableau value |
| ------------------------ | ------------------------: |
| Eligible seller-orders   |                     1,772 |
| Late seller-orders       |                       172 |
| Seller late rate         |                     9.71% |
| Marketplace contribution |                     2.63% |
| Excess late              |                     +53.4 |
| Seller GMV               |   approximately R$200,473 |
| Queue                    | `investigate_high_excess` |

This seller is used as the representative static screenshot example.

### Monthly seller detail

Source:

```text
seller_month
```

Grain:

```text
(seller_id, purchase_month)
```

The monthly seller view remains separate from the lifetime `seller_performance` source.

It uses:

```text
is_comparable_trend_window = True
```

and shows:

* seller late rate;
* late seller-orders;
* eligible seller-orders.

The 6.69% marketplace seller-order late-rate benchmark may be shown as context.

### Seller-selection interaction

A Tableau dashboard action explicitly maps:

```text
seller_performance.seller_id
    →
seller_month.seller_id
```

Selecting a seller from the scatter or investigation table updates:

* Selected Seller;
* Monthly Performance.

The interaction does not affect:

* Executive marketplace KPI cards;
* marketplace delivery-rate trends;
* unrelated geography or category views.

When no seller is selected, seller-specific detail may remain blank rather than displaying an aggregated multi-seller trend.

### Queue-filter validation

Default:

```text
Investigation Queue = All
Is On Watchlist = True
```

Expected default seller count:

```text
25
```

Filtering to:

```text
investigate_high_excess
```

should produce:

```text
14 sellers
```

No marketplace date filter is applied to seller lifetime metrics.

### Seller Performance interpretation

The page supports the following operational use:

1. identify sellers with unusually high late rates;
2. distinguish those sellers from sellers with large absolute marketplace impact;
3. prioritize sellers with meaningful volume and excess late;
4. separate investigation cases from recent-deterioration monitoring cases;
5. inspect the selected seller's monthly performance without affecting marketplace-level KPIs.

### Screenshot

Current portfolio screenshot:

```text
dashboard/screenshots/seller_investigation.png
```

If renamed later, the preferred page-aligned filename is:

```text
dashboard/screenshots/seller_performance.png
```

Either filename represents the same validated Page 3 artifact.

Page 3 should not be modified further unless a data, metric, interaction, or reconciliation defect is discovered.


# Tableau artifact inventory

Current Tableau workbook:

```text
dashboard/marketplace_operations.twb
```

Current screenshots:

```text
dashboard/
├── marketplace_operations.twb
└── screenshots/
    ├── executive_overview.png
    ├── root_cause.png
    └── seller_investigation.png
```

Remaining expected page screenshots:

```text
dashboard/screenshots/geography_product.png
dashboard/screenshots/monitoring.png
```

The Tableau workbook is a portfolio artifact.

Dashboard CSV inputs remain reproducible through:

```bash
python -m python.scripts.build_dashboard_layer
python -m python.scripts.export_dashboard_extracts
```

Manual edits to the generated CSV extracts are not permitted.


# Interaction and grain checks

The Tableau workbook must preserve the approved analytical grains.

| Area                          | Grain                        |
| ----------------------------- | ---------------------------- |
| Executive marketplace metrics | order                        |
| Monthly marketplace trend     | order × month                |
| Seller performance            | seller-order                 |
| Seller monthly detail         | seller-order × month         |
| Geography                     | customer-destination order   |
| Category                      | seller-order-category        |
| Delivery review               | reviewed order               |
| Delay-band review             | reviewed order by delay band |

Important distinctions:

```text
Late marketplace orders:      6,534 full extract
Late marketplace seller-orders: 6,547
```

These values represent different grains and must not be forced to reconcile.

Similarly:

```text
Comparable marketplace order late rate:      6.82%
Marketplace seller-order late-rate benchmark: 6.69%
```

These rates serve different analytical populations.


# Tableau calculation rules

Allowed:

* display formatting;
* aliases;
* stakeholder-friendly field names;
* simple labels;
* percentage formatting;
* reference lines;
* tooltips;
* navigation actions;
* explicit seller-selection actions;
* `SUM(numerator) / SUM(denominator)` when the visual grain is valid.

Not allowed:

* recalculating late-delivery status from timestamps;
* recalculating watchlist membership;
* recalculating excess late with a different benchmark;
* averaging monthly rates into a period rate;
* averaging monthly medians into a period median;
* creating a new seller score;
* creating new causal conclusions;
* modifying extract values manually.


# Filter behavior

Filters must remain scoped to analytically compatible datasets.

| Filter                       | Valid use                                       |
| ---------------------------- | ----------------------------------------------- |
| Reporting scope              | Executive cards; comparable/full snapshot views |
| Purchase month               | Monthly trend datasets                          |
| Seller / investigation queue | Seller Performance                              |
| Customer state               | Geography views                                 |
| Product category             | Category views                                  |
| Delivery class               | Root Cause / customer-experience views          |

Unsafe behaviors include:

* using a seller filter to modify Executive marketplace cards;
* using a category filter to recalculate marketplace late orders;
* using customer-state filters on seller lifetime metrics;
* applying one workbook-wide date filter to seller lifetime metrics;
* using seller-order late units as marketplace late orders.


# Usability checks

A stakeholder can:

* answer marketplace status, direction, scale, and first investigation area from Executive without leaving Page 1;
* identify the major November 2017, February–March 2018, and August 2018 deterioration patterns;
* distinguish seller handling, carrier transit, and promise-setting behavior on Root Cause;
* identify carrier transit as the strongest fulfillment signal during the major deterioration episode;
* recognize August 2018 as a separate promise-compression pattern;
* see the customer-experience difference between early and late delivery without interpreting it causally;
* distinguish seller failure rate from marketplace impact on Seller Performance;
* inspect eligible volume, late units, rate, contribution, excess late, commercial exposure, recent change, and monthly seller performance;
* filter the seller investigation queue without changing Executive marketplace totals.

Every important rate retains denominator or volume context.

Incomplete or sparse periods are not silently treated as comparable peer periods.

Order-grain and seller-order-grain metrics remain separate.

No regression table, composite seller score, predictive alert, or unsupported causal claim is exposed.


# Refresh validation

Refresh sequence:

```bash
python -m python.scripts.build_metric_layer
python -m python.scripts.build_analysis_layer
python -m python.scripts.build_dashboard_layer
python -m python.scripts.export_dashboard_extracts
pytest tests/test_dashboard_layer.py -q
```

After refreshing:

1. dashboard CSVs are replaced in place;
2. Tableau reconnects to the same certified extract paths;
3. Executive headline metrics still reconcile;
4. episode values still reconcile;
5. seller watchlist counts still reconcile;
6. no Tableau Prep or Excel transformation modifies certified fields;
7. no manually edited CSV is introduced.


# Remaining Tableau pages

The following pages are still pending validation:

## Page 4 — Geography & Product

Expected sources:

```text
geography_performance
geography_month
category_performance
```

Key future validation cases include:

```text
RJ comparable:
1,492 / 12,219 = 12.21%

RJ February 2018:
299 / 879 = 34.02%

RJ March 2018:
298 / 864 = 34.49%

SP August 2018:
285 / 3,164 = 9.01%

SP August late-order contribution:
285 / 393 = 72.5%
```

Category rates must retain volume context and category late units must not be treated as additive to marketplace seller-order late totals.

Status:

```text
NOT YET VALIDATED
```

## Page 5 — Monitoring

Expected sources:

```text
fulfillment_trends
marketplace_rolling
geography_month
seller_performance
```

Key future validation cases include:

```text
Latest complete comparable date:
2018-08-31

Rolling 30-day:
364 / 6,045

Rolling 90-day:
669 / 18,278
```

Monitoring must be described as historical analytical monitoring rather than real-time, streaming, predictive, or production alerting.

Status:

```text
NOT YET VALIDATED
```



# Final workbook approval rule

The Tableau workbook is not fully certified until all five pages pass reconciliation and usability review.

Current page status:

| Page                | Status            |
| ------------------- | ----------------- |
| Executive Overview  | PASS / FROZEN     |
| Root Cause          | PASS / FROZEN     |
| Seller Performance  | PASS / FROZEN     |
| Geography & Product | NOT YET VALIDATED |
| Monitoring          | NOT YET VALIDATED |

Any future change to a frozen page that alters:

* metric values;
* filters;
* grain;
* calculated fields;
* Tableau relationships;
* dashboard actions;
* source selection;

requires re-running the relevant validation checks.

The Excel weekly review, if built later, must read the same certified dashboard extracts and must not become a second KPI layer.
