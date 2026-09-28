**Table 5: Bayesian Mixed-Effects Model Fit Comparison (Paired loo_compare SE; Models 2, 4, 5 use Phase 1 convergence refits)**

elpd_diff and se_diff are the *paired* expected log predictive density difference and its standard error relative to the best-fitting model, from loo::loo_compare(). The ratio column (elpd_diff / se_diff) is a rough guide only: |ratio| > ~2 is suggestive that a comparison exceeds sampling noise, not proof of a materially better model.



|Model                                                     |WAIC (SE)           | elpd_diff| se_diff|ratio |
|:---------------------------------------------------------|:-------------------|---------:|-------:|:-----|
|1. Crossed Random Intercepts                              |48,917.4<br>(228.9) |     -93.2|    13.5|-6.90 |
|2. Constrained Slopes (Like Only) [REFIT]                 |48,828.1<br>(229.5) |     -48.6|     9.5|-5.13 |
|3. Constrained Slopes (Under- & Overclaiming)             |48,822.1<br>(229.5) |     -45.6|     9.1|-5.00 |
|4. Constrained Slopes (Overclaiming & Consistent) [REFIT] |48,730.9<br>(229.5) |       0.0|     0.0|—   |
|5. Full Crossed Random Slopes [REFIT]                     |48,731.4<br>(229.5) |      -0.2|     1.3|-0.20 |
