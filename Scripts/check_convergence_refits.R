#' @title Convergence Diagnostics for the 3 Refit Models
#' @description Same diagnostics as Scripts/check_convergence.R, applied to
#'   the Phase 1 refits (Models 2, 4, 5) to confirm the higher adapt_delta
#'   and larger iter/warmup resolved the Rhat elevation found in the
#'   original fits. One model loaded (and dropped) at a time.

library(brms)
library(posterior)
library(dplyr)

dir.create("cache", showWarnings = FALSE)

model_files <- c(
  "2. Constrained Slopes (Like Only) [REFIT]"                 = "rds/model_brms_constrained_likeonly_refit.rds",
  "4. Constrained Slopes (Overclaiming & Consistent) [REFIT]"  = "rds/model_brms_constrained_over_true_refit.rds",
  "5. Full Crossed Random Slopes [REFIT]"                      = "rds/model_brms_slopes_refit.rds"
)

diagnose_one <- function(label, path) {
  cat(sprintf("[%s] Loading %s ...\n", Sys.time(), path))
  fit <- readRDS(path)

  draws <- as_draws_array(fit)
  param_smry <- posterior::summarise_draws(draws, "rhat", "ess_bulk", "ess_tail")

  np <- brms::nuts_params(fit)
  n_divergent <- sum(np$Parameter == "divergent__" & np$Value > 0)
  max_treedepth <- 13  # refits used control = list(max_treedepth = 13)
  td <- np[np$Parameter == "treedepth__", ]
  n_max_treedepth_hit <- sum(td$Value >= max_treedepth, na.rm = TRUE)

  res <- data.frame(
    Model = label,
    Max_Rhat = round(max(param_smry$rhat, na.rm = TRUE), 4),
    Min_ESS_Bulk = round(min(param_smry$ess_bulk, na.rm = TRUE), 0),
    Min_ESS_Tail = round(min(param_smry$ess_tail, na.rm = TRUE), 0),
    N_Divergent = n_divergent,
    N_Max_Treedepth = n_max_treedepth_hit,
    stringsAsFactors = FALSE
  )
  rm(fit, draws); gc()
  res
}

results <- lapply(names(model_files), function(nm) {
  tryCatch(
    diagnose_one(nm, model_files[[nm]]),
    error = function(e) {
      cat(sprintf("ERROR diagnosing %s: %s\n", nm, conditionMessage(e)))
      data.frame(Model = nm, Max_Rhat = NA, Min_ESS_Bulk = NA, Min_ESS_Tail = NA,
                 N_Divergent = NA, N_Max_Treedepth = NA, stringsAsFactors = FALSE)
    }
  )
})

diag_df <- bind_rows(results)

flag_row <- function(row) {
  issues <- c()
  if (!is.na(row$Max_Rhat) && row$Max_Rhat > 1.01) issues <- c(issues, "Rhat>1.01")
  if (!is.na(row$Min_ESS_Bulk) && row$Min_ESS_Bulk < 400) issues <- c(issues, "ESS_bulk<400")
  if (!is.na(row$Min_ESS_Tail) && row$Min_ESS_Tail < 400) issues <- c(issues, "ESS_tail<400")
  if (!is.na(row$N_Divergent) && row$N_Divergent > 0) issues <- c(issues, sprintf("%d divergences", row$N_Divergent))
  if (length(issues) == 0) "OK" else paste(issues, collapse = "; ")
}
diag_df$Flag <- vapply(seq_len(nrow(diag_df)), function(i) flag_row(diag_df[i, ]), character(1))

write.csv(diag_df, "cache/diagnostics_summary_refits.csv", row.names = FALSE)

sink("cache/table_diagnostics_refits.md")
cat("**Model Diagnostics: Convergence Summary for the 3 Refit Specifications**\n\n")
print(knitr::kable(diag_df, format = "pipe"))
sink()

cat("\n===== REFIT DIAGNOSTICS SUMMARY =====\n")
print(diag_df)
cat("======================================\n")
