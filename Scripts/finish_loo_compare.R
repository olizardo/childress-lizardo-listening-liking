#' @title Final Paired Model Comparison via loo_compare() (Corrected /\WAIC/SE)
#' @description Builds the corrected Table 5 using the FINAL model set: the
#'   two models that failed convergence checks in Phase 1 (Models 2 and 5)
#'   are represented by their refit (iter=4000/warmup=1500/adapt_delta=0.97)
#'   versions; Model 4 (also flagged) by its refit; Models 1 and 3 (which
#'   passed diagnostics) keep their original fits. Each model is loaded,
#'   its WAIC criterion computed/extracted, and then dropped from memory
#'   before the next is loaded, so peak memory stays bounded to one
#'   brmsfit at a time. loo_compare() is then run on the small saved WAIC
#'   objects only.

library(brms)
library(loo)
library(dplyr)

dir.create("cache", showWarnings = FALSE)
dir.create("rds", showWarnings = FALSE)

model_paths <- c(
  "1. Crossed Random Intercepts"                     = "rds/model_brms_intercepts.rds",
  "2. Constrained Slopes (Like Only) [REFIT]"         = "rds/model_brms_constrained_likeonly_refit.rds",
  "3. Constrained Slopes (Under- & Overclaiming)"     = "rds/model_brms_constrained_under_over.rds",
  "4. Constrained Slopes (Overclaiming & Consistent) [REFIT]" = "rds/model_brms_constrained_over_true_refit.rds",
  "5. Full Crossed Random Slopes [REFIT]"             = "rds/model_brms_slopes_refit.rds"
)
waic_out_paths <- c(
  "rds/waic_brms_intercepts.rds",
  "rds/waic_brms_constrained_likeonly_refit.rds",
  "rds/waic_brms_constrained_under_over.rds",
  "rds/waic_brms_constrained_over_true_refit.rds",
  "rds/waic_brms_slopes_refit.rds"
)
names(waic_out_paths) <- names(model_paths)

waics <- list()
for (nm in names(model_paths)) {
  out_path <- waic_out_paths[[nm]]
  if (file.exists(out_path)) {
    cat(sprintf("[%s] Reusing cached WAIC: %s\n", nm, out_path))
    waics[[nm]] <- readRDS(out_path)
    next
  }
  cat(sprintf("[%s] Loading %s ...\n", nm, model_paths[[nm]]))
  fit <- readRDS(model_paths[[nm]])
  if (is.null(fit$criteria$waic)) {
    cat("  No WAIC attached; computing now...\n")
    fit <- add_criterion(fit, "waic", cores = 4)
  }
  waics[[nm]] <- fit$criteria$waic
  saveRDS(waics[[nm]], out_path)
  rm(fit); gc()
}

cat("Running loo_compare() for paired elpd_diff / se_diff...\n")
cmp <- loo_compare(waics)
cmp_df <- as.data.frame(cmp)
cmp_df$Model <- rownames(cmp_df)

waic_point <- data.frame(
  Model = names(waics),
  WAIC = sapply(waics, function(w) w$estimates["waic", "Estimate"]),
  WAIC_SE = sapply(waics, function(w) w$estimates["waic", "SE"]),
  stringsAsFactors = FALSE
)

full <- cmp_df %>%
  select(Model, elpd_diff, se_diff) %>%
  left_join(waic_point, by = "Model") %>%
  mutate(
    Model = factor(Model, levels = names(model_paths)),
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
cat("**Table 5: Bayesian Mixed-Effects Model Fit Comparison (Paired loo_compare SE; Models 2, 4, 5 use Phase 1 convergence refits)**\n\n")
cat("elpd_diff and se_diff are the *paired* expected log predictive density ")
cat("difference and its standard error relative to the best-fitting model, ")
cat("from loo::loo_compare(). The ratio column (elpd_diff / se_diff) is a ")
cat("rough guide only: |ratio| > ~2 is suggestive that a comparison exceeds ")
cat("sampling noise, not proof of a materially better model.\n\n")
print(knitr::kable(fmt, format = "pipe"))
sink()

cat("\n===== FINAL PAIRED MODEL COMPARISON =====\n")
print(full)
cat("===========================================\n")
cat("Saved cache/table5_fit.md and cache/table5_fit_raw.csv\n")
