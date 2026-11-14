#' @title Convergence diagnostics for a corrected brms fit (parameterized)
#' @usage Rscript diagnose_mN_corrected.R <N>
args <- commandArgs(trailingOnly = TRUE)
N <- as.integer(args[1])
stopifnot(!is.na(N), N %in% 1:5)
library(brms)
library(posterior)

fit <- readRDS(sprintf("rds/model_brms_m1_corrected_v2.rds", N))
draws <- as_draws_df(fit)
rhat_values <- summarise_draws(draws, "rhat")$rhat
ess_values <- summarise_draws(draws, "ess_bulk", "ess_tail")
sampler_params <- nuts_params(fit)
n_divergent <- sum(sampler_params$Value[sampler_params$Parameter == "divergent__"])
n_treedepth <- sum(sampler_params$Value[sampler_params$Parameter == "treedepth__"] >= 13)
waic_result <- readRDS(sprintf("rds/waic_m1_corrected_v2.rds", N))

lines <- c(
  sprintf("Model 1 v2 (corrected) diagnostics", N),
  sprintf("Posterior draws: %d", nrow(draws)),
  sprintf("Max R-hat: %.4f", max(rhat_values, na.rm = TRUE)),
  sprintf("Parameters with R-hat > 1.01: %d of %d", sum(rhat_values > 1.01, na.rm = TRUE), length(rhat_values)),
  sprintf("Min bulk ESS: %.0f", min(ess_values$ess_bulk, na.rm = TRUE)),
  sprintf("Min tail ESS: %.0f", min(ess_values$ess_tail, na.rm = TRUE)),
  sprintf("Divergent transitions: %d", n_divergent),
  sprintf("Iterations hitting max treedepth 13: %d", n_treedepth),
  "",
  "WAIC:",
  capture.output(print(waic_result))
)
dir.create("cache", showWarnings = FALSE)
writeLines(lines, sprintf("cache/diagnostics_m1_v2.txt", N))
cat(lines, sep = "\n")
