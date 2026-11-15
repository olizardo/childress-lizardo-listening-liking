# Paired loo_compare on the CORRECTED fits (data_coding fix, 2026-11-11).
# Uses only the small waic_m{N}_corrected.rds objects; never loads full fits.
# Writes cache/table5_fit.md (does NOT touch legacy table5_fit.md).
# Models whose WAIC object is absent are skipped with a warning, so the table
# can be regenerated as each new fit lands.
library(brms)
library(loo)
library(dplyr)

labels <- c(
  "1. Crossed Random Intercepts",
  "2. Constrained Slopes (Overclaiming)",
  "3. Constrained Slopes (Underclaiming & Overclaiming)",
  "4. Constrained Slopes (Overclaiming & Consistent Engagement)",
  "5. Full Crossed Random Slopes",
  "6. Full Crossed Slopes, Education Slopes by Genre",
  "7. Random Intercepts, Quadratic Arts Term",
  "8. Full Crossed Slopes, Arts × College Preference Ratio",
  "9. Model 6 Structure, Education × College Preference Ratio",
  "10. Model 6 Structure, Education Slopes on Overclaiming & Consistent Engagement",
  "11. Model 4 Structure, Arts & Education Slopes on Overclaiming & Consistent Engagement",
  "12. Full Crossed Slopes, Arts × Prestige and Popularity",
  "13. Model 6 Structure, Arts and Education × College Preference Ratio",
  "14. Model 4 Structure, Arts and Education × College Preference Ratio",
  "15. Model 4 Structure, Both Interactions on the Liking States Only"
)
# Which exposures carry a genre-level random slope, and in which equations.
# Read off the formulas in the fit scripts; the three states are the equations
# (Underclaiming = Listen Only, Overclaiming = Like Only, Consistent Engagement
# = Both). Every model also carries respondent and genre random intercepts.
crossed_slopes <- c(
  "1. Crossed Random Intercepts" = "None",
  "2. Constrained Slopes (Overclaiming)" = "Arts: Overclaiming only",
  "3. Constrained Slopes (Underclaiming & Overclaiming)" = "Arts: Underclaiming, Overclaiming",
  "4. Constrained Slopes (Overclaiming & Consistent Engagement)" = "Arts: Overclaiming, Consistent Engagement",
  "5. Full Crossed Random Slopes" = "Arts: all three equations",
  "6. Full Crossed Slopes, Education Slopes by Genre" = "Arts and education: all three equations",
  "7. Random Intercepts, Quadratic Arts Term" = "None (fixed quadratic arts term)",
  "8. Full Crossed Slopes, Arts × College Preference Ratio" = "Arts: all three equations",
  "9. Model 6 Structure, Education × College Preference Ratio" = "Arts and education: all three equations",
  "10. Model 6 Structure, Education Slopes on Overclaiming & Consistent Engagement" = "Arts: all three equations; education: Overclaiming, Consistent Engagement",
  "11. Model 4 Structure, Arts & Education Slopes on Overclaiming & Consistent Engagement" = "Arts and education: Overclaiming, Consistent Engagement",
  "12. Full Crossed Slopes, Arts × Prestige and Popularity" = "Arts: all three equations",
  "13. Model 6 Structure, Arts and Education × College Preference Ratio" = "Arts and education: all three equations",
  "14. Model 4 Structure, Arts and Education × College Preference Ratio" = "Arts and education: Overclaiming, Consistent Engagement",
  "15. Model 4 Structure, Both Interactions on the Liking States Only" = "Arts and education: Overclaiming, Consistent Engagement"
)

waic_paths <- c(
  "rds/waic_m1_corrected_v2.rds",
  sprintf("rds/waic_m%d_corrected.rds", 2:5),
  "rds/waic_m6_educslopes.rds",
  "rds/waic_m7_artsquad.rds",
  "rds/waic_m8_prestigeslopes.rds",
  "rds/waic_m9_educprestige.rds",
  "rds/waic_m10_educslopes_liking.rds",
  "rds/waic_m11_educarts_liking.rds",
  "rds/waic_m12_arts_mods_listened.rds",
  "rds/waic_m13_both_moderators.rds",
  "rds/waic_m14_both_mods_restricted.rds",
  "rds/waic_m15_interactions_liking.rds"
)
names(waic_paths) <- labels

missing <- waic_paths[!file.exists(waic_paths)]
if (length(missing)) {
  warning("Skipping ", length(missing), " model(s) with no WAIC object yet: ",
          paste(missing, collapse = ", "), call. = FALSE)
  waic_paths <- waic_paths[file.exists(waic_paths)]
}
stopifnot("rds/waic_m1_corrected_v2.rds" %in% waic_paths)  # baseline must be present
labels_used <- names(waic_paths)

waics <- setNames(lapply(waic_paths, readRDS), labels_used)  # lapply drops names; restore them

# Baseline is the random-intercepts model (Model 1), not the best-fitting model.
# loo_compare() always scores against the best fit, so the paired differences are
# built by hand from the per-observation expected log predictive densities.
base <- waics[[1]]$pointwise[, "elpd_waic"]
full <- data.frame(
  Model = labels_used,
  elpd_diff = vapply(waics, function(w) sum(w$pointwise[, "elpd_waic"] - base), numeric(1)),
  se_diff = vapply(waics, function(w) {
    x <- w$pointwise[, "elpd_waic"] - base
    sqrt(length(x) * var(x))
  }, numeric(1)),
  WAIC = vapply(waics, function(w) w$estimates["waic", "Estimate"], numeric(1)),
  WAIC_SE = vapply(waics, function(w) w$estimates["waic", "SE"], numeric(1)),
  row.names = NULL
) %>%
  mutate(
    Model = factor(Model, levels = labels),
    `Crossed genre slopes` = unname(crossed_slopes[as.character(Model)]),
    ratio = ifelse(se_diff == 0, NA, elpd_diff / se_diff)
  ) %>%
  arrange(Model)

stopifnot(!any(is.na(full$`Crossed genre slopes`)))

write.csv(full, "cache/table5_fit_raw.csv", row.names = FALSE)

fmt <- full %>%
  mutate(
    `WAIC (SE)` = sprintf("%s<br>(%s)", format(round(WAIC, 1), big.mark = ","), round(WAIC_SE, 1)),
    `Predictive density difference` = round(elpd_diff, 1),
    `Standard error of difference` = round(se_diff, 1),
    `Difference in standard error units` = ifelse(is.na(ratio), "\u2014", sprintf("%.2f", ratio))
  ) %>%
  select(Model, `Crossed genre slopes`, `WAIC (SE)`, `Predictive density difference`,
         `Standard error of difference`, `Difference in standard error units`)

word_num <- c("one", "two", "three", "four", "five", "six", "seven",
              "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen")[nrow(full)]
sink("cache/table5_fit.md")
cat(sprintf("**Table 5 (corrected data): Paired comparison of %s fitted models against the random-intercepts baseline (28,655 obs / 1,450 respondents)**\n\n",
            word_num))
cat("elpd_diff and se_diff are the *paired* expected log predictive density ")
cat("difference and its standard error relative to the random-intercepts ")
cat("baseline (Model 1), computed from each model's per-observation elpd_waic. ")
cat("The ratio column (elpd_diff / se_diff) is a rough guide only: ")
cat("|ratio| > ~2 is suggestive, not proof, that a comparison exceeds sampling noise.")
cat(" The crossed-slopes column names which exposure carries a genre-level random ")
cat("slope and in which equation; every model also has respondent and genre random intercepts.")
if (length(missing)) {
  cat("\n\nFitted but not yet scored: ",
      paste(sub("^[0-9]+\\. ", "", missing), collapse = "; "), ".", sep = "")
}
cat("\n\n")
print(knitr::kable(fmt, format = "pipe"))
sink()

cat("\n===== CORRECTED PAIRED MODEL COMPARISON =====\n")
print(as.data.frame(full))
cat("=============================================\n")
cat("Models scored:", nrow(full), "of", length(labels), "\n")
cat("Saved cache/table5_fit.md and cache/table5_fit_raw.csv\n")
