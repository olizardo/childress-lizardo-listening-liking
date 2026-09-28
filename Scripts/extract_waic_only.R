#' @title Standalone WAIC Extraction (run as a one-shot Rscript subprocess)
#' @description Loads a single brmsfit .rds file, ensures it has a WAIC
#'   criterion attached, and saves ONLY the small waic object to a separate
#'   output path. Intended to be invoked via `Rscript Scripts/extract_waic_only.R
#'   <input_rds> <output_rds>` so that the multi-hundred-MB to multi-GB
#'   in-memory footprint of a full brmsfit is released the moment the
#'   subprocess exits, rather than accumulating across models in a shared
#'   interactive R session.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("Usage: Rscript extract_waic_only.R <input_rds> <output_rds>")
input_path <- args[1]
output_path <- args[2]

library(brms)

cat(sprintf("[%s] Loading %s ...\n", Sys.time(), input_path))
fit <- readRDS(input_path)

if (is.null(fit$criteria$waic)) {
  cat(sprintf("[%s] No WAIC attached; computing now...\n", Sys.time()))
  fit <- add_criterion(fit, "waic", cores = 4)
} else {
  cat(sprintf("[%s] WAIC already attached.\n", Sys.time()))
}

waic_obj <- fit$criteria$waic
saveRDS(waic_obj, output_path)
cat(sprintf("[%s] Saved WAIC object to %s\n", Sys.time(), output_path))
print(waic_obj)
