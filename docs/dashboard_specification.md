# Dashboard Specification

Tableau presentation layer for the certified marketplace operations analysis.

The dashboard answers:

> Which operational problems are driving poor marketplace customer experience, where are they concentrated, and where should Operations look first?

It communicates approved findings. It does not become a second analytical system.

# Source of truth

```text
metrics.*  →  analysis.*  →  dashboard.* views / CSV extracts  →  Tableau
```

* Headline KPIs come from certified SQL. Tableau may format values and compute `SUM(numerator) / SUM(denominator)` at the dataset grain.
* Tableau must not redefine on-time, late, GMV, negative reviews, excess late, or watchlist membership.
* Late **orders** (6,534) and late **seller-orders** (6,547) are different grains.
* Category late counts are not additive to marketplace late seller-orders.
* Seller review rates are order-level CX associated with a seller, not a seller penalty.
* Connect the extracts below as **separate Tableau sources**. Do not blend them into one model.

# Tableau datasets

| Source | Grain | Unit | Pages |
|---|---|---|---|
| `executive_overview` | `reporting_scope` | order | Executive cards |
| `fulfillment_trends` | `purchase_month` | order | Executive, Root Cause, Monitoring |
| `fulfillment_components` | `(analysis_period, delivery_class)` | order | Root Cause |
| `marketplace_rolling` | `purchase_date` | order | Monitoring |
| `delivery_review` | `delivery_class` | order | Executive, Root Cause |
| `delay_band_reviews` | `delay_band` | order | Root Cause |
| `seller_performance` | `seller_id` | seller-order | Seller, Monitoring watchlist |
| `seller_month` | `(seller_id, purchase_month)` | seller-order | Seller detail |
| `category_performance` | `(reporting_scope, product_category)` | seller-order-category | Geography & Product |
| `geography_performance` | `(reporting_scope, customer_state)` | order | Geography & Product |
| `geography_month` | `(customer_state, purchase_month)` | order | Geography, Monitoring |

CSV copies live in `outputs/dashboard/`.

Safe relationship: `seller_performance.seller_id` → `seller_month.seller_id` (1:N). Keep monthly measures at month grain.

Unsafe: relating sellers or categories to marketplace monthly late orders; treating watchlist late units as late orders; averaging monthly rates instead of summing numerators and denominators.

# Headline KPI mapping

Rates are stored as proportions.

| Dashboard metric | Field | Source | Definition |
|---|---|---|---|
| Orders | `all_orders` | `metrics.kpi_marketplace` / comparable `kpi_orders` | All certified orders |
| Eligible orders | `delivery_performance_eligible` | same | Delivered with actual and estimated dates |
| On-time % | `on_time_delivery_rate` | same | (Early + exact-date) / eligible |
| Late % | `late_delivery_rate` | same | Late / eligible |
| GMV | `gmv` | same | `SUM(price)` |
| Late GMV | `late_gmv` | same | Merchandise on late orders |
| Negative review % | `negative_review_rate` | same | Score ≤ 2 / reviewed |
| Monthly late % | `late_delivery_rate` | `analysis.marketplace_month_trend` | Late / eligible that month |
| Handling / transit / promise | `median_*` | `analysis.fulfillment_month`, `fulfillment_decomposition` | Separate certified durations |
| Window / baseline late % | `comparable_window_late_rate`, `early_2017_baseline_late_rate` | monthly certified sums | 6.82% and 3.52% reference lines |
| Seller late % | `seller_late_rate` | `analysis.seller_prioritization` | Late seller-orders / eligible |
| Contribution | `seller_late_contribution` | same | Seller late units / 6,547 |
| Excess late | `excess_late_marketplace` | same | Observed − eligible × 6,547 / 97,811 |
| State / category late % | `late_rate` | segment and category extracts | Show volume with the rate |
| Late vs early negative review % | `negative_review_rate` | `analysis.delivery_class_review_rates` | 62.34% vs 9.11% |
| Rolling 30/90 | `late_rate_30d`, `late_rate_90d` | `analysis.marketplace_day` | Use full comparable windows only |

Default Executive scope is the comparable window: **95,453 eligible / 6,509 late / 6.82%**; late GMV **R$982,502.52**.

# Five pages

## Executive Overview

Status, trend, scale, and first place to look.

* Six cards from `executive_overview` (comparable default): orders, GMV, on-time %, late % with count, late GMV, negative review %.
* Monthly late rate and eligible volume from `fulfillment_trends`, with 3.52% and 6.82% reference lines. Annotate Nov 2017, Feb–Mar 2018, and Aug 2018.
* Short signal strip: transit spikes; August promise compression in São Paulo; late vs early reviews; 25-seller queue / 21.5% of late seller-orders.
* High-excess preview: filter `seller_performance` to `is_high_excess`.

## Root Cause

Keep seller handling, carrier transit, and promised window as separate visuals.

* Late vs early vs exact-date medians from `fulfillment_components`.
* Three monthly component trends from `fulfillment_trends`.
* Late rate with transit (spike months) and late rate with promised window (August).
* CX from `delivery_review` and `delay_band_reviews`. No regression tables.

## Seller Performance

High failure rate is not the same as high marketplace impact.

* Default filter: `is_on_watchlist`.
* Scatter: eligible volume vs late rate, sized by late units, colored by `investigation_queue`, reference line at 6.69%.
* Table: volume, late, rate, contribution, excess, GMV, July/August change, reasons, queue.
* Selected-seller sparkline from `seller_month`.

## Geography & Product

Concentration only. Do not imply causation.

* Customer-state snapshot from `geography_performance` (comparable window). Highlight RJ and SP.
* RJ/SP monthly from `geography_month` (Feb–Mar RJ ~34%; August SP 285 of 393 late orders).
* Category snapshot from `category_performance`. Show volume; mute `is_low_sample` rates.

## Monitoring

Latest certified performance. No new alerts.

* Latest comparable month and reference lines from `fulfillment_trends`.
* Rolling 30/90 from `marketplace_rolling` where the window is full and comparable (latest: 2018-08-31).
* RJ months from `geography_month` (`meets_rj_monitoring_rule`).
* Watchlist / recent deterioration from `seller_performance` flags.

# Filters and interactions

| Filter | Use on | Do not use on |
|---|---|---|
| Comparable vs full extract | Executive cards; category and geography snapshots | Lifetime seller facts |
| Purchase month | `fulfillment_trends`, `geography_month`, `seller_month`, `marketplace_rolling` | Executive snapshot, seller lifetime, CX class/band tables |
| Seller / queue flags | `seller_performance`, `seller_month` | Marketplace KPI cards |
| Customer state | Geography visuals | Seller or category extracts |
| Category | Category visual | Marketplace late **orders** |
| Delivery class | Root-cause components and CX | Seller lifetime |
| Customer type | Absent | — |

Page navigation is explicit. Highlight across grains; do not apply one workbook-level filter to every source. Every rate tooltip should show numerator, denominator, and unit.

# Seller watchlist

There is no separate watchlist extract. Filter `seller_performance`.

A seller is on the watchlist if it meets at least one approved rule from `analysis.seller_watchlist`:

| Rule | Definition |
|---|---|
| High excess | Eligible ≥ 100 and excess late ≥ 15 |
| High rate and high volume | Eligible ≥ 100, late rate ≥ marketplace + 3 pp, late units ≥ 30 |
| Recent deterioration | August eligible ≥ 30 and July–August late-rate increase ≥ 5 pp |

Result: **25 sellers**, **1,408 late seller-orders**, **14 high-excess**.

| Flag / field | Meaning |
|---|---|
| `is_on_watchlist` | Any approved rule |
| `is_high_excess` | First investigation set (14) |
| `is_high_rate_high_volume` | Rate-and-volume rule |
| `is_recently_deteriorating` | 11 sellers flagged; 10 are not already high-excess and are monitor-only |
| `investigation_queue` | Display label: high-excess first, then monitor recent, then high-rate |
| `watchlist_reasons` | Transparent entry reasons |

No composite score. No SLA tier.

# Refresh

```bash
python -m python.scripts.build_metric_layer
python -m python.scripts.build_analysis_layer
python -m python.scripts.build_dashboard_layer
python -m python.scripts.export_dashboard_extracts
pytest tests/test_dashboard_layer.py -q
```

Tableau connects to `outputs/dashboard/*.csv` or to PostgreSQL schema `dashboard` (local default port `55432` via `.env`).

SQL lives in `sql/dashboard/`. No undocumented Tableau Prep or Excel steps.
