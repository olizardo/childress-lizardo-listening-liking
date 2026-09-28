#' @title Paired Model Comparison via loo_compare() (Corrected ΔWAIC/SE)
#' @description The original cache/table5_fit.md reported ΔWAIC as the raw
#'   scalar difference between independently computed WAIC point estimates,
#'   alongside each model's *marginal* WAIC standard error (~229 for every
#'   model). That is not a valid basis for judging whether a model
#'   comparison is credible: loo_compare() computes the *paired*
#'   pointwise elpd_diff and its se_diff, which is what should be reported.
#'
#' @param model_paths Named character vector of model file paths, in the
#'   same order as the manuscript's Table 5. Defaults to the original 5
#'   fits; pass the *_refit paths once Phase 1 convergence refits complete.

library(brms)
library(loo)
library(dplyr)

dir.create("cache", showWarnings = FALSE)

compute_loo_comparison <- function(model_paths, out_prefix = "cache/table5_fit") {
  cat("Loading models and ensuring each has a WAIC criterion attached...\n")
  waics <- list()
  for (nm in names(model_paths)) {
    cat(sprintf("[%s] %s\n", nm, model_paths[[nm]]))
    fit <- readRDS(model_paths[[nm]])
    if (is.null(fit$criteria$waic)) {
      fit <- add_criterion(fit, "waic", cores = 4)
    }
    waics[[nm]] <- fit$criteria$waic
    rm(fit); gc()
  }

  cat("Running loo_compare() for paired elpd_diff / se_diff...\n")
  cmp <- loo_compare(waics)
  cmp_df <- as.data.frame(cmp)
  cmp_df$Model <- rownames(cmp_df)

  # loo_compare ranks by elpd (best first); reattach original WAIC point
  # estimates/SEs and reorder to the manuscript's canonical model order.
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

  write.csv(full, paste0(out_prefix, "_raw.csv"), row.names = FALSE)

  fmt <- full %>%
    mutate(
      `WAIC (SE)` = sprintf("%s<br>(%s)", format(round(WAIC, 1), big.mark = ","), round(WAIC_SE, 1)),
      elpd_diff = round(elpd_diff, 1),
      se_diff = round(se_diff, 1),
      ratio = ifelse(is.na(ratio), "—", sprintf("%.2f", ratio))
    ) %>%
    select(Model, `WAIC (SE)`, elpd_diff, se_diff, ratio)

  sink(paste0(out_prefix, ".md"))
  cat("**Table 5: Bayesian Mixed-Effects Model Fit Comparison (Paired loo_compare SE)**\n\n")
  cat("elpd_diff and se_diff are the *paired* expected log predictive density ")
  cat("difference and its standard error relative to the best-fitting model, ")
  cat("from loo::loo_compare(). The ratio column (elpd_diff / se_diff) is a ")
  cat("rough guide only: |ratio| > ~2 is suggestive that a comparison exceeds ")
  cat("sampling noise, not proof of a materially better model.\n\n")
  print(knitr::kable(fmt, format = "pipe"))
  sink()

  cat("\n===== PAIRED MODEL COMPARISON =====\n")
  print(full)
  cat("=====================================\n")

  full
}

if (sys.nframe() == 0) {
  model_paths_original <- c(
    "1. Crossed Random Intercepts" = "rds/model_brms_intercepts.rds",
    "2. Constrained Slopes (Like Only)" = "rds/model_brms_constrained_likeonly.rds",
    "3. Constrained Slopes (Under- & Overclaiming)" = "rds/model_brms_constrained_under_over.rds",
    "4. Constrained Slopes (Overclaiming & Consistent)" = "rds/model_brms_constrained_over_true.rds",
    "5. Full Crossed Random Slopes" = "rds/model_brms_slopes.rds"
  )
  compute_loo_comparison(model_paths_original)
}
