#' @title Paired LOO comparison of Model 6 against Model 5
#' @description M6 is M5 plus education slopes in the genre random effects.
#'   Raw WAIC favours M6 by about 236 points, but the two estimates are
#'   dependent (same data, nested models), so the comparison has to be paired
#'   on the pointwise predictive densities rather than read off the separate
#'   WAIC totals. This script computes loo for each fit, then runs
#'   loo_compare. Fits are loaded one at a time to keep memory bounded.
#'
#'   Output: rds/loo_m5_corrected.rds, rds/loo_m6_educslopes.rds,
#'           cache/m6_vs_m5_loo_compare.csv

suppressMessages({
  library(cmdstanr)
  library(brms)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

get_loo <- function(fit_path, loo_path) {
  if (file.exists(loo_path)) {
    cat("Reusing", loo_path, "\n")
    return(readRDS(loo_path))
  }
  cat(sprintf("[%s] Loading %s ...\n", Sys.time(), fit_path))
  fit <- readRDS(fit_path)
  cat(sprintf("[%s] Computing loo ...\n", Sys.time()))
  l <- brms::loo(fit, cores = 4)
  saveRDS(l, loo_path)
  rm(fit)
  gc()
  l
}

loo_m5 <- get_loo("rds/model_brms_m5_corrected.rds", "rds/loo_m5_corrected.rds")
loo_m6 <- get_loo("rds/model_brms_m6_educslopes.rds", "rds/loo_m6_educslopes.rds")

cmp <- brms::loo_compare(list("M5 (no education slopes)" = loo_m5,
                              "M6 (education slopes)" = loo_m6))

cat("\n===== PAIRED LOO COMPARISON, M5 vs M6 =====\n")
print(cmp)

dir.create("cache", showWarnings = FALSE)
out <- as.data.frame(cmp)
out$model <- rownames(out)
write.csv(out, "cache/m6_vs_m5_loo_compare.csv", row.names = FALSE)
cat("Saved cache/m6_vs_m5_loo_compare.csv\n")
