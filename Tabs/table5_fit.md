**Table 5 (corrected data): Paired loo_compare on corrected fits (28,655 obs / 1,450 respondents)**

The second through fourth columns come from a *paired* leave-one-out comparison (loo::loo_compare()) scored against the best-fitting model. The predictive density difference is each model's shortfall in expected log predictive density relative to that model, the next column is the standard error of that shortfall, and the last expresses the shortfall in standard error units. A shortfall below about two standard errors is conventionally read as a tie.



|Model                                             |WAIC (SE)           |Predictive density difference|Standard error of difference|Difference in standard error units|
|:-------------------------------------------------|:-------------------|---------:|-------:|:-----|
|1. Crossed Random Intercepts                      |50,808.0<br>(252.7) |    -107.4|    14.5|-7.43 |
|2. Constrained Slopes (Like Only)                 |50,724.3<br>(253.5) |     -65.5|    11.1|-5.93 |
|3. Constrained Slopes (Under- & Overclaiming)     |50,721.7<br>(253.5) |     -64.3|    11.1|-5.81 |
|4. Constrained Slopes (Overclaiming & Consistent) |50,593.2<br>(253.7) |       0.0|     0.0|—     |
|5. Full Crossed Random Slopes                     |50,595.3<br>(253.7) |      -1.0|     1.2|-0.86 |
