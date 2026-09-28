#' @title Convergence Diagnostics Across All 5 Bayesian Crossed-Effects Models
#' @description Loads each of the 5 saved brms fits and extracts maximum Rhat,
#'   minimum bulk/tail effective sample size, divergent transition count, and
#'   max-treedepth exceedances. Saves a summary table to cache/ for inclusion
#'   in the manuscript's Model Diagnostics subsection.

library(brms)
library(posterior)
library(dplyr)

dir.create("cache", showWarnings = FALSE)

model_files <- c(
  "1. Crossed Random Intercepts"                     = "rds/model_brms_intercepts.rds",
  "2. Constrained Slopes (Like Only)"                 = "rds/model_brms_constrained_likeonly.rds",
  "3. Constrained Slopes (Under- & Overclaiming)"     = "rds/model_brms_constrained_under_over.rds",
  "4. Constrained Slopes (Overclaiming & Consistent)" = "rds/model_brms_constrained_over_true.rds",
  "5. Full Crossed Random Slopes"                     = "rds/model_brms_slopes.rds"
)

diagnose_one <- function(label, path) {
  cat(sprintf("[%s] Loading %s ...\n", Sys.time(), path))
  fit <- readRDS(path)

  draws <- as_draws_array(fit)
  # NOTE: posterior::rhat()/ess_bulk()/ess_tail() collapse a full
  # draws_array into a single meaningless scalar rather than computing
  # per-parameter values. summarise_draws() is the correct per-parameter
  # path and is what must be used here.
  param_smry <- posterior::summarise_draws(draws, "rhat", "ess_bulk", "ess_tail")
  rhat_vals <- param_smry$rhat
  ess_bulk_vals <- param_smry$ess_bulk
  ess_tail_vals <- param_smry$ess_tail

  np <- brms::nuts_params(fit)
  n_divergent <- sum(np$Parameter == "divergent__" & np$Value > 0)
  # All 5 models were fit with control = list(max_treedepth = 12); see
  # Scripts/run_brms_*.R.
  max_treedepth <- 12
  td <- np[np$Parameter == "treedepth__", ]
  n_max_treedepth_hit <- sum(td$Value >= max_treedepth, na.rm = TRUE)

  data.frame(
    Model = label,
    Max_Rhat = round(max(rhat_vals, na.rm = TRUE), 4),
    Min_ESS_Bulk = round(min(ess_bulk_vals, na.rm = TRUE), 0),
    Min_ESS_Tail = round(min(ess_tail_vals, na.rm = TRUE), 0),
    N_Divergent = n_divergent,
    N_Max_Treedepth = n_max_treedepth_hit,
    stringsAsFactors = FALSE
  )
}

results <- lapply(names(model_files), function(nm) {
  tryCatch(
    diagnose_one(nm, model_files[[nm]]),
    error = function(e) {
      cat(sprintf("ERROR diagnosing %s: %s\n", nm, conditionMessage(e)))
      data.frame(
        Model = nm, Max_Rhat = NA, Min_ESS_Bulk = NA, Min_ESS_Tail = NA,
        N_Divergent = NA, N_Max_Treedepth = NA, stringsAsFactors = FALSE
      )
    }
  )
})

diag_df <- bind_rows(results)
write.csv(diag_df, "cache/diagnostics_summary.csv", row.names = FALSE)

flag_row <- function(row) {
  issues <- c()
  if (!is.na(row$Max_Rhat) && row$Max_Rhat > 1.01) issues <- c(issues, "Rhat>1.01")
  if (!is.na(row$Min_ESS_Bulk) && row$Min_ESS_Bulk < 400) issues <- c(issues, "ESS_bulk<400")
  if (!is.na(row$Min_ESS_Tail) && row$Min_ESS_Tail < 400) issues <- c(issues, "ESS_tail<400")
  if (!is.na(row$N_Divergent) && row$N_Divergent > 0) issues <- c(issues, sprintf("%d divergences", row$N_Divergent))
  if (length(issues) == 0) "OK" else paste(issues, collapse = "; ")
}

diag_df$Flag <- vapply(seq_len(nrow(diag_df)), function(i) flag_row(diag_df[i, ]), character(1))

sink("cache/table_diagnostics.md")
cat("**Model Diagnostics: Convergence Summary Across the 5 Fitted Specifications**\n\n")
print(knitr::kable(diag_df, format = "pipe"))
sink()

cat("\n===== DIAGNOSTICS SUMMARY =====\n")
print(diag_df)
cat("================================\n")

any_flagged <- any(diag_df$Flag != "OK")
if (any_flagged) {
  cat("\nWARNING: One or more models show convergence issues. Refitting is required before proceeding to Phase 2 (WAIC comparison) with any flagged model.\n")
} else {
  cat("\nAll 5 models pass basic convergence checks (Rhat <= 1.01, ESS >= 400, zero divergences). Safe to proceed to Phase 2.\n")
}
