#' @title Finish Prior Sensitivity Comparison (post-hoc, no refitting)
#' @description Both fits already finished sampling and are saved to disk; the
#'   original job was OOM-killed only at the step that loads the baseline fit
#'   alongside the wide-prior one (3 GB request). This script extracts the
#'   child_arts coefficients from one fit at a time and drops each fit before
#'   loading the next, so peak memory is a single fit.
#'
#'   Input:  rds/model_brms_m1_corrected_v2.rds   normal(0, 1.5)
#'           rds/model_brms_m1_wideprior_corrected.rds  normal(0, 3)
#'   Output: cache/prior_sensitivity_model1.csv

suppressMessages({
  library(cmdstanr)
  library(brms)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")
dir.create("cache", showWarnings = FALSE)

extract_child_arts <- function(path, label) {
  cat(sprintf("[%s] Loading %s ...\n", Sys.time(), path))
  fit <- readRDS(path)
  draws <- brms::as_draws_df(fit)
  states <- c("muListenOnly", "muLikeOnly", "muBoth")
  rows <- lapply(states, function(s) {
    col <- paste0("b_", s, "_child_arts")
    x <- draws[[col]]
    data.frame(
      Specification = label, State = gsub("^mu", "", s),
      Mean = round(mean(x), 3), SD = round(sd(x), 3),
      CrI_2.5 = round(quantile(x, 0.025), 3), CrI_97.5 = round(quantile(x, 0.975), 3),
      p_bayes = 2 * min(mean(x <= 0), mean(x >= 0))
    )
  })
  rm(fit, draws); gc()
  dplyr::bind_rows(rows)
}

comparison <- dplyr::bind_rows(
  extract_child_arts("rds/model_brms_m1_corrected_v2.rds",
                     "Corrected M1 v2: normal(0, 1.5)"),
  extract_child_arts("rds/model_brms_m1_wideprior_corrected.rds",
                     "Wider prior: normal(0, 3)")
)

write.csv(comparison, "cache/prior_sensitivity_model1.csv", row.names = FALSE)
cat("\n===== CHILD_ARTS COEFFICIENT COMPARISON ACROSS FIXED-EFFECT PRIOR WIDTH =====\n")
print(comparison)
cat("Saved to cache/prior_sensitivity_model1.csv\n")
