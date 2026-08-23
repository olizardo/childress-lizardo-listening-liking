**Table 5: Bayesian Mixed-Effects Model Fit Comparison**



|Model                                             |ListenOnly |LikeOnly |Both | Params|     ELPD| ELPD_SE|    WAIC| WAIC_SE| Delta_WAIC|
|:-------------------------------------------------|:----------|:--------|:----|------:|--------:|-------:|-------:|-------:|----------:|
|1. Crossed Random Intercepts (Baseline)           |—          |—        |—    |   4820| -24458.7|   115.2| 48917.4|   230.4|        0.0|
|2. Constrained Slopes (Like Only)                 |—          |Yes      |—    |   4840| -24412.0|   114.8| 48823.9|   229.6|      -93.5|
|3. Constrained Slopes (Under- & Overclaiming)     |Yes        |Yes      |—    |   4860| -24411.0|   114.7| 48822.1|   229.5|      -95.3|
|4. Constrained Slopes (Overclaiming & Consistent) |—          |Yes      |Yes  |   4860| -24367.5|   114.7| 48735.1|   229.5|     -182.3|
|5. Full Crossed Random Slopes (Preferred)         |Yes        |Yes      |Yes  |   4880| -24366.2|   114.3| 48732.4|   228.6|     -185.0|
