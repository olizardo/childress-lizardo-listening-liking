**Table 5 (corrected data): Paired comparison of eight fitted models against the random-intercepts baseline (28,655 obs / 1,450 respondents)**

The second through fourth columns come from a *paired* comparison of the per-observation expected log predictive densities, scored against the random-intercepts model (Model 1). The predictive density difference is each model's gain over that baseline, the next column is the standard error of that gain, and the last expresses the gain in standard error units. A gain below about two standard errors is conventionally read as a tie.

|Model                                             |WAIC (SE)           |Predictive density difference|Standard error of difference|Difference in standard error units|
|:-------------------------------------------------|:-------------------|---------:|-------:|:-----|
|1. Crossed Random Intercepts                      |50,808.0<br>(252.7) |       0.0|     0.0|—     |
|2. Constrained Slopes (Like Only)                 |50,724.3<br>(253.5) |      41.9|     9.2|4.56  |
|3. Constrained Slopes (Under- & Overclaiming)     |50,721.7<br>(253.5) |      43.1|     9.2|4.69  |
|4. Constrained Slopes (Overclaiming & Consistent) |50,593.2<br>(253.7) |     107.4|    14.5|7.43  |
|5. Full Crossed Random Slopes                     |50,595.3<br>(253.7) |     106.4|    14.5|7.34  |
|6. Plus Genre-Specific Education Slopes           |50,358.8<br>(254.3) |     224.6|    20.9|10.74 |
|7. Plus Quadratic Arts Term                       |50,806.8<br>(252.8) |       0.6|     1.6|0.38  |
|8. Plus Arts × College Preference Ratio           |50,594.1<br>(253.7) |     107.0|    14.8|7.25  |

Rows 1–5 are the models compared in the manuscript's earlier fit table; rows 6–8 add the education-slopes, quadratic-arts, and arts-by-prestige specifications. Model 9 (education × College Preference Ratio inside the likelihood) is not yet fitted. All eight rows use the same 28,655 person–genre observations. The criterion is WAIC; because 2.0% of observations in Models 6 and 7 have p_waic above 0.4, a PSIS-LOO comparison is the preferred confirmatory check for those two rows and that comparison is still running on the cluster. Model 4 and Model 5 were a tie under the earlier best-model baseline (difference 1.0, SE 1.2); read against Model 1 they both gain about 107 elpd, so the choice between them is unaffected.
