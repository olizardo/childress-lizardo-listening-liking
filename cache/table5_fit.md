**Table 5 (corrected data): Paired comparison of seven fitted models against the random-intercepts baseline (28,655 obs / 1,450 respondents)**

elpd_diff and se_diff are the *paired* expected log predictive density difference and its standard error relative to the random-intercepts baseline (Model 1), computed from each model's per-observation elpd_waic. The ratio column (elpd_diff / se_diff) is a rough guide only: |ratio| > ~2 is suggestive, not proof, that a comparison exceeds sampling noise.

Fitted but not yet scored: rds/waic_m9_educprestige.rds; rds/waic_m10_educslopes_liking.rds; rds/waic_m11_educarts_liking.rds.



|Model                                                        |WAIC (SE)           | Predictive density difference| Standard error of difference|Difference in standard error units |
|:------------------------------------------------------------|:-------------------|-----------------------------:|----------------------------:|:----------------------------------|
|1. Crossed Random Intercepts                                 |50,808.0<br>(252.7) |                           0.0|                          0.0|—                                  |
|2. Constrained Slopes (Overclaiming)                         |50,724.3<br>(253.5) |                          41.9|                          9.2|4.56                               |
|3. Constrained Slopes (Underclaiming & Overclaiming)         |50,721.7<br>(253.5) |                          43.1|                          9.2|4.69                               |
|4. Constrained Slopes (Overclaiming & Consistent Engagement) |50,593.2<br>(253.7) |                         107.4|                         14.5|7.43                               |
|5. Full Crossed Random Slopes                                |50,595.3<br>(253.7) |                         106.4|                         14.5|7.34                               |
|6. Full Crossed Slopes, Education Slopes by Genre            |50,358.8<br>(254.3) |                         224.6|                         20.9|10.74                              |
|7. Random Intercepts, Quadratic Arts Term                    |50,806.8<br>(252.8) |                           0.6|                          1.6|0.38                               |
|8. Full Crossed Slopes, Arts × College Preference Ratio      |50,594.1<br>(253.7) |                         107.0|                         14.8|7.25                               |
