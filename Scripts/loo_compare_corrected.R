# Paired loo_compare on the CORRECTED fits (data_coding fix, 2026-11-11).
# Uses only the small waic_m{N}_corrected.rds objects; never loads full fits.
# Writes cache/table5_fit.md (does NOT touch legacy table5_fit.md).
library(brms)
library(loo)
library(dplyr)

labels <- c(
  "1. Crossed Random Intercepts",
  "2. Constrained Slopes (Like Only)",
  "3. Constrained Slopes (Under- & Overclaiming)",
  "4. Constrained Slopes (Overclaiming & Consistent)",
  "5. Full Crossed Random Slopes"
)
waic_paths <- c(sprintf("rds/waic_m1_corrected_v2.rds", 1),
  sprintf("rds/waic_m%d_corrected.rds", 2:5))
names(waic_paths) <- labels

missing <- waic_paths[!file.exists(waic_paths)]
if (length(missing)) stop("Missing WAIC files: ", paste(missing, collapse=", "))

waics <- setNames(lapply(waic_paths, readRDS), labels)  # lapply drops names; restore them
cmp <- loo_compare(waics)
cmp_df <- as.data.frame(cmp)
cmp_df$Model <- cmp_df$model  # newer loo returns a model column; rownames are indices


full <- cmp_df %>%
  select(Model, elpd_diff, se_diff, WAIC = waic, WAIC_SE = se_waic) %>%
  mutate(
    Model = factor(Model, levels = labels),
    ratio = ifelse(se_diff == 0, NA, elpd_diff / se_diff)
  ) %>%
  arrange(Model)

write.csv(full, "cache/table5_fit_raw.csv", row.names = FALSE)

fmt <- full %>%
  mutate(
    `WAIC (SE)` = sprintf("%s<br>(%s)", format(round(WAIC, 1), big.mark = ","), round(WAIC_SE, 1)),
    elpd_diff = round(elpd_diff, 1),
    se_diff = round(se_diff, 1),
    ratio = ifelse(is.na(ratio), "—", sprintf("%.2f", ratio))
  ) %>%
  select(Model, `WAIC (SE)`, elpd_diff, se_diff, ratio)

sink("cache/table5_fit.md")
cat("**Table 5 (corrected data): Paired loo_compare on corrected fits (28,655 obs / 1,450 respondents)**\n\n")
cat("elpd_diff and se_diff are the *paired* expected log predictive density ")
cat("difference and its standard error relative to the best-fitting model, ")
cat("from loo::loo_compare() on WAIC criteria. The ratio column ")
cat("(elpd_diff / se_diff) is a rough guide only: |ratio| > ~2 is suggestive, ")
cat("not proof, that a comparison exceeds sampling noise.\n\n")
print(knitr::kable(fmt, format = "pipe"))
sink()

cat("\n===== CORRECTED PAIRED MODEL COMPARISON =====\n")
print(as.data.frame(full))
cat("=============================================\n")
cat("Saved cache/table5_fit.md and cache/table5_fit_raw.csv\n")
