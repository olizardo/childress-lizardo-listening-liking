#' @title Recompute WAIC for a saved fit (post-hoc, no refitting)
#' @description Several 2026-11-13/14 cluster jobs finished sampling and saved
#'   their fit, then were OOM-killed while computing WAIC because the submit
#'   scripts requested only 3-6 GB (the M1-M5 fits all requested 48 GB). This
#'   script loads one saved fit and recomputes WAIC only. It deliberately does
#'   NOT write back to the fit file, so a kill mid-write cannot damage it.
#'
#'   Usage: Rscript Scripts/finish_waic_tag.R <tag>
#'     reads  rds/model_brms_<tag>.rds
#'     writes rds/waic_<tag>.rds

suppressMessages({
  library(cmdstanr)
  library(brms)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("Usage: Rscript Scripts/finish_waic_tag.R <tag>")
tag <- args[[1]]
fit_path <- file.path("rds", paste0("model_brms_", tag, ".rds"))
out_path <- file.path("rds", paste0("waic_", tag, ".rds"))
stopifnot(file.exists(fit_path))

cat("Loading", fit_path, "...\n")
fit <- readRDS(fit_path)
cat("Draws:", nrow(brms::as_draws_df(fit)), "\n")

cat("Computing WAIC...\n")
waic_res <- brms::waic(fit)
saveRDS(waic_res, out_path)

cat("\n===== WAIC:", tag, "=====\n")
print(waic_res)
cat("Saved to", out_path, "\n")
