# Customer Experience Impact Analysis

## Objective

Assess how delivery performance is associated with customer review outcomes.

Reviews are analyzed at the **order level**. Missing reviews remain missing and are not treated as positive or negative.

All delivery, review, GMV, and repeat-customer fields come from the certified KPI layer. Results are observational and do not establish causality.


## 1. Review Coverage

Overall review coverage is high:

```text
usable reviews:     97,530 / 99,441 orders
delivered coverage: 94,782 / 96,478 = 98.24%
```

However, missing reviews are not random.

| Population | Late rate | Repeat share |
| ---------- | --------: | -----------: |
| Reviewed   |     6.65% |        2.81% |
| Unreviewed |    13.38% |       33.08% |

Unreviewed delivered orders are about twice as likely to be late, and repeat orders have lower review coverage.

This means observed reviews may underrepresent some late-delivery experiences. Scores are therefore not imputed for missing reviews.


## 2. Delivery Performance and Reviews

Among delivery-performance-eligible reviewed orders:

| Delivery class | Reviewed | Negative rate | Avg score |
| -------------- | -------: | ------------: | --------: |
| Early          |   87,203 |         9.11% |      4.30 |
| On time        |    1,264 |        12.26% |      4.04 |
| Late           |    6,307 |        62.34% |      2.27 |

Late delivery is the strongest observed customer-experience split in the analysis.

The exact on-time group is relatively small, so the main comparison is between early and late deliveries.


## 3. Delay Severity Matters

Negative-review rates rise sharply after the promised delivery date:

| Delay band      | Negative rate |
| --------------- | ------------: |
| Early           |   about 9–11% |
| On time         |        12.26% |
| 1–3 days late   |        31.97% |
| 4–7 days late   |        67.53% |
| 8–14 days late  |        80.29% |
| 15–30 days late |        81.72% |
| 31+ days late   |        68.01% |

Even a 1–3 day delay is associated with a large increase in negative reviews.

The pattern is not driven only by extreme delays:

```text
all eligible late:  62.34%
exclude 31+ days:   62.04%
exclude p99 delay:  59.72%
```

Extreme delays amplify poor reviews, but they do not create the overall relationship.


## 4. The Pattern Persists Across Segments

The late-versus-early review gap remains visible across:

* first and repeat orders;
* order-value bands;
* major customer states;
* adequately sized product categories.

For example:

| GMV band  | Early negative | Late negative |
| --------- | -------------: | ------------: |
| < R$50    |          7.70% |        60.52% |
| R$50–99   |          8.71% |        61.36% |
| R$100–199 |          9.52% |        63.46% |
| R$200+    |         11.99% |        64.95% |

Order value changes the baseline slightly, but it does not explain the late-delivery review gap.

Geography and product category also shift baseline review rates. These differences should be treated as context rather than separate root causes.


## Key Findings

1. **Late delivery is strongly associated with worse reviews.**
   Negative-review rates increase from 9.11% for early deliveries to 62.34% for late deliveries.

2. **Delay severity matters.**
   Negative reviews rise sharply after the promised date and remain high for severe delays.

3. **The relationship is broadly consistent.**
   It remains visible across order value, customer geography, product category, and first-versus-repeat purchases.

4. **Review missingness matters.**
   Unreviewed orders are more likely to be late, so reviews should not be treated as a perfectly random sample.

5. **Extreme delays are not driving the entire result.**
   Sensitivity checks leave the main late-versus-early gap intact.


## Operational Interpretation

The customer-experience analysis reinforces the fulfillment findings:

> Delivery reliability is closely associated with customer satisfaction, and larger delivery misses are associated with substantially worse review outcomes.

This strengthens the case for prioritizing fulfillment problems identified in the upstream root-cause and seller analyses.

However, review outcomes alone should not be used to assign seller responsibility or determine penalties.


## Limitations

* The analysis is observational and does not estimate a causal effect.
* Reviews are measured at the order level, including multi-seller orders.
* Missing reviews are not random.
* Exact on-time deliveries are relatively uncommon.
* Product category, geography, order value, and time period may influence both delivery outcomes and reviews.
* No regression or hypothesis testing is included here; those belong in [`docs/statistical_validation.md`](statistical_validation.md).


## Reproduction

```bash
python -m python.scripts.build_analysis_layer
python -m python.scripts.run_customer_experience
python -m python.scripts.run_analysis_validation
pytest tests/test_customer_experience.py -q
```

Primary artifacts:

```text
sql/analysis/customer_experience.sql
python/scripts/customer_experience.py
python/scripts/run_customer_experience.py
python/notebooks/customer_experience_analysis.ipynb

outputs/analysis/review_coverage.csv
outputs/analysis/delivery_class_review_rates.csv
outputs/analysis/delay_band_reviews.csv
outputs/analysis/segment_review_performance.csv

outputs/figures/cx_delivery_class.png
outputs/figures/cx_delay_bands.png
outputs/figures/cx_gmv_stratification.png
outputs/figures/cx_review_selection.png
```
