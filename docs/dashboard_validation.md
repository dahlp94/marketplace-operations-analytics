# Dashboard Validation

Reconcile Tableau to certified SQL before treating the workbook as finished.

Period rates must use `SUM(late) / SUM(eligible)`, not the average of monthly rates. If Tableau and SQL agree but both disagree with a finding document, treat that as an upstream documentation issue.

```bash
python -m python.scripts.build_dashboard_layer
python -m python.scripts.export_dashboard_extracts
pytest tests/test_dashboard_layer.py -q
```

# Critical cases

| Case | Source | Target |
|---|---|---|
| Executive full extract | `executive_overview` | 99,441 orders; 96,470 eligible; 89,936 on-time; 6,534 late; GMV 13,591,643.70; late GMV 985,924.34; 14,197 / 97,530 negative reviews |
| Comparable late rate | `executive_overview` | 6,509 / 95,453 = 6.82%; late GMV 982,502.52 |
| February–March 2018 | `fulfillment_trends` | 2,254 / 13,558 = 16.62% (926 + 1,328 late) |
| August 2018 | `fulfillment_trends` | 393 / 6,351 = 6.19%; median promised window 14 days |
| High-excess seller | `seller_performance` `4a3ca9315b744ce9f8e9374361493884` | 1,772 eligible; 172 late; 9.71%; excess +53.4; on watchlist; high-excess |
| Watchlist | `seller_performance` where `is_on_watchlist` | 25 sellers; 1,408 late seller-orders; 14 high-excess |
| Rio February 2018 | `geography_month` | 299 / 879 = 34.02% |
| São Paulo August 2018 | `geography_month` | 285 / 3,164 = 9.01%; 285 of 393 August late orders |
| Category non-additivity | `category_performance` full extract | GMV sums to marketplace GMV; late units ≠ 6,547 |
| Rolling 30/90 | `marketplace_rolling` | Latest full comparable date 2018-08-31; 364 / 6,045 and 669 / 18,278 |
| Early vs late reviews | `delivery_review` | 9.11% vs 62.34% |
| Refresh | rebuild + CSV replace | Headline cases above still match; no manual extract edits |

Comparable-window Rio snapshot is **1,492 / 12,219 = 12.21%** from `analysis.segment_fulfillment_performance`. Use that SQL row, not older narrative totals.

# Usability checks

A stakeholder can answer status, direction, and first investigation area on Executive; separate handling / transit / promise on Root Cause; and open one seller with volume, rate, contribution, and excess. Every rate shows a denominator. Incomplete months are marked. No regression table is exposed.

The Excel weekly review, if built later, must read these same extracts.
