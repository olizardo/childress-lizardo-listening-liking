# Reduced fit-comparison table for the manuscript (Table 5).
# Four specifications only; the full fifteen-model ladder stays in
# cache/table5_fit.md, produced by make_table5_fit_comparison.R. The two
# all-equations rows (Models 5 and 6) were dropped on 2026-11-15, since the
# baseline shows childhood arts and education are null in the underclaiming
# equation and the restricted fits tie their all-equations counterparts.
#
# Reads only the small waic_m*.rds objects; never loads full fits.
# Writes cache/table5_fit_reduced.md and cache/table5_fit_reduced.csv.
library(loo)
library(dplyr)

# Row order and wording are the manuscript's, not the model numbering's.
reduced <- data.frame(
  row = c(
    "1. Random Intercepts (Reference)",
    "2. Arts Random Slopes, Overclaiming and Consistent Engagement",
    "3. Arts and Education Random Slopes, Overclaiming and Consistent Engagement",
    "4. Restricted Slopes with Both Ratio Interactions"
  ),
  model = c(
    "1. Crossed Random Intercepts",
    "4. Constrained Slopes (Overclaiming & Consistent Engagement)",
    "11. Model 4 Structure, Arts & Education Slopes on Overclaiming & Consistent Engagement",
    "14. Model 4 Structure, Arts and Education × College Preference Ratio"
  ),
  slopes = c(
    "None",
    "Arts: Overclaiming & Consistent Engagement",
    "Arts and education: Overclaiming & Consistent Engagement",
    "Arts and education: Overclaiming & Consistent Engagement, both moderated by the ratio"
  ),
  waic = c(
    "rds/waic_m1_corrected_v2.rds",
    "rds/waic_m4_corrected.rds",
    "rds/waic_m11_educarts_liking.rds",
    "rds/waic_m14_both_mods_restricted.rds"
  ),
  stringsAsFactors = FALSE
)

missing <- reduced$waic[!file.exists(reduced$waic)]
if (length(missing)) {
  stop("WAIC object(s) missing, table cannot be built: ",
       paste(basename(missing), collapse = ", "), call. = FALSE)
}

w <- lapply(reduced$waic, readRDS)
base <- w[[1]]$pointwise[, "elpd_waic"]

out <- data.frame(
  Model = reduced$row,
  `Crossed genre slopes` = reduced$slopes,
  WAIC = vapply(w, function(x) x$estimates["waic", "Estimate"], numeric(1)),
  WAIC_SE = vapply(w, function(x) x$estimates["waic", "SE"], numeric(1)),
  elpd_diff = vapply(w, function(x) sum(x$pointwise[, "elpd_waic"] - base), numeric(1)),
  se_diff = vapply(w, function(x) {
    d <- x$pointwise[, "elpd_waic"] - base
    sqrt(length(d) * var(d))
  }, numeric(1)),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
out$ratio <- ifelse(out$se_diff == 0, NA, out$elpd_diff / out$se_diff)

write.csv(out, "cache/table5_fit_reduced.csv", row.names = FALSE)

fmt <- out |>
  mutate(
    `WAIC (SE)` = sprintf("%s<br>(%s)", format(round(WAIC, 1), big.mark = ","),
                          round(WAIC_SE, 1)),
    `Improvement over Model 1` = round(elpd_diff, 1),
    `Standard error of improvement` = round(se_diff, 1),
    `Improvement in standard errors` = ifelse(is.na(ratio), "\u2014", sprintf("%.2f", ratio))
  ) |>
  select(Model, `Crossed genre slopes`, `WAIC (SE)`, `Improvement over Model 1`,
         `Standard error of improvement`, `Improvement in standard errors`)

sink("cache/table5_fit_reduced.md")
cat("**Table 5 (reduced): paired comparison of four specifications against the random-intercepts baseline (28,655 obs / 1,450 respondents)**\n\n")
cat("Improvements are paired expected log predictive density differences against ")
cat("the random-intercepts baseline, computed from each model's per-observation ")
cat("elpd_waic. The ratio column is a rough guide only.\n\n")
print(knitr::kable(fmt, format = "pipe"))
sink()

print(fmt)
cat("\nSaved cache/table5_fit_reduced.md and cache/table5_fit_reduced.csv\n")
