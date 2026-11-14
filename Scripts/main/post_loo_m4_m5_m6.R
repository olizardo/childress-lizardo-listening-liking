#' @title PSIS-LOO for Models 4, 5, and 6
#' @description The eight-model fit table scores models on WAIC, and 2% of
#'   observations in Models 6 and 7 have p_waic above 0.4, which is the regime
#'   where WAIC's effective-parameter correction is least reliable. This script
#'   recomputes the comparison under PSIS-LOO for the three fits where the
#'   ranking matters: M4, M5 (tied under WAIC) and M6 (the WAIC leader).
#'   No refitting; fits are loaded one at a time to bound memory.
#'
#'   Existing loo objects are reused, so re-running after a partial run or
#'   picking up rds/loo_m5_corrected.rds from post_m6_vs_m5_loo.R is cheap.
#'
#'   Output: rds/loo_m4_corrected.rds, rds/loo_m5_corrected.rds,
#'           rds/loo_m6_educslopes.rds,
#'           cache/loo_m4_m5_m6_compare.csv,
#'           cache/loo_pareto_k_summary.csv

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(loo)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

get_loo <- function(fit_path, loo_path) {
  if (file.exists(loo_path)) {
    cat("Reusing", loo_path, "\n")
    return(readRDS(loo_path))
  }
  stopifnot(file.exists(fit_path))
  cat(sprintf("[%s] Loading %s ...\n", Sys.time(), fit_path))
  fit <- readRDS(fit_path)
  cat(sprintf("[%s] Computing loo ...\n", Sys.time()))
  l <- brms::loo(fit, cores = 4)
  saveRDS(l, loo_path)
  rm(fit)
  gc()
  l
}

models <- list(
  "M4 (overclaiming & consistent slopes)" =
    list(fit = "rds/model_brms_m4_corrected.rds", loo = "rds/loo_m4_corrected.rds"),
  "M5 (full crossed slopes)" =
    list(fit = "rds/model_brms_m5_corrected.rds", loo = "rds/loo_m5_corrected.rds"),
  "M6 (full slopes + education slopes)" =
    list(fit = "rds/model_brms_m6_educslopes.rds", loo = "rds/loo_m6_educslopes.rds")
)

loos <- lapply(models, function(m) get_loo(m$fit, m$loo))

dir.create("cache", showWarnings = FALSE)

# Pareto-k diagnostics: k > 0.7 means the importance-sampling approximation is
# unreliable for that observation; k > 1 would require reloo().
k_summary <- do.call(rbind, lapply(names(loos), function(nm) {
  k <- loos[[nm]]$diagnostics$pareto_k
  data.frame(model = nm, n_obs = length(k),
             share_k_gt_0.7 = mean(k > 0.7),
             share_k_gt_1 = mean(k > 1),
             max_k = max(k))
}))
rownames(k_summary) <- NULL
write.csv(k_summary, "cache/loo_pareto_k_summary.csv", row.names = FALSE)
cat("\n===== PARETO-K SUMMARY =====\n")
print(k_summary, row.names = FALSE)

cmp <- loo_compare(loos)
cat("\n===== PAIRED LOO COMPARISON (scored against the best fit) =====\n")
print(cmp)

# Mirror the fit table's convention: differences against a fixed baseline,
# taken here as Model 4. loo_compare always scores against the best fit, so the
# fixed-baseline differences are built from the per-observation elpd values.
base <- loos[[1]]$pointwise[, "elpd_loo"]
fixed <- data.frame(
  model = names(loos),
  elpd_loo = vapply(loos, function(l) l$estimates["elpd_loo", "Estimate"], numeric(1)),
  se_elpd_loo = vapply(loos, function(l) l$estimates["elpd_loo", "SE"], numeric(1)),
  p_loo = vapply(loos, function(l) l$estimates["p_loo", "Estimate"], numeric(1)),
  elpd_diff_vs_M4 = vapply(loos, function(l) sum(l$pointwise[, "elpd_loo"] - base), numeric(1)),
  se_diff_vs_M4 = vapply(loos, function(l) {
    x <- l$pointwise[, "elpd_loo"] - base
    sqrt(length(x) * var(x))
  }, numeric(1)),
  row.names = NULL
)
write.csv(fixed, "cache/loo_m4_m5_m6_compare.csv", row.names = FALSE)
cat("\n===== DIFFERENCES AGAINST MODEL 4 =====\n")
print(fixed, row.names = FALSE)
cat("\nSaved cache/loo_m4_m5_m6_compare.csv and cache/loo_pareto_k_summary.csv\n")
