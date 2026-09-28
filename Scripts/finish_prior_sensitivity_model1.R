#' @title Finish Prior Sensitivity Comparison (post-hoc, no refitting)
#' @description The two underlying models already finished sampling and are
#'   saved to disk; this script only extracts and compares the child_arts
#'   coefficients, loading (and dropping) one model at a time.

library(brms)
library(dplyr)

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
      CrI_2.5 = round(quantile(x, 0.025), 3), CrI_97.5 = round(quantile(x, 0.975), 3)
    )
  })
  res <- bind_rows(rows)
  rm(fit, draws); gc()
  res
}

comparison <- bind_rows(
  extract_child_arts("rds/model_brms_intercepts.rds", "Original: normal(0, 1.5)"),
  extract_child_arts("rds/model_brms_intercepts_wideprior.rds", "Wider prior: normal(0, 3)")
)

write.csv(comparison, "cache/prior_sensitivity_model1.csv", row.names = FALSE)
cat("\n===== CHILD_ARTS COEFFICIENT COMPARISON ACROSS FIXED-EFFECT PRIOR WIDTH =====\n")
print(comparison)
cat("Saved to cache/prior_sensitivity_model1.csv\n")
