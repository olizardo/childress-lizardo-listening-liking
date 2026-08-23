#' @title Compute WAIC for Constrained Bayesian Model on Hoffman2
#' @description Computes Widely Applicable Information Criterion (WAIC) for
#'   the constrained LikeOnly random-slopes brms model and saves output to rds/.

options(repos = c(CRAN = "https://cloud.r-project.org"))
library(brms)

cat(sprintf("[%s] Starting WAIC calculation on Hoffman2...\n", Sys.time()))
cat(sprintf("[%s] Loading rds/model_brms_constrained_likeonly.rds...\n", Sys.time()))

model_path <- "rds/model_brms_constrained_likeonly.rds"
if (!file.exists(model_path)) {
  if (file.exists("model_brms_constrained_likeonly.rds")) {
    model_path <- "model_brms_constrained_likeonly.rds"
  } else {
    stop("Model file not found!")
  }
}

fit <- readRDS(model_path)
n_slots <- as.integer(Sys.getenv("NSLOTS", unset = 8))
cat(sprintf("[%s] Model loaded successfully. Computing WAIC using %d cores...\n", Sys.time(), n_slots))

t_start <- Sys.time()
waic_res <- waic(fit, cores = n_slots)
t_end <- Sys.time()

cat(sprintf("[%s] WAIC computation completed in %.2f minutes.\n", Sys.time(), as.numeric(difftime(t_end, t_start, units = "mins"))))
print(waic_res)

dir.create("rds", showWarnings = FALSE)
saveRDS(waic_res, "rds/waic_brms_constrained.rds")
cat(sprintf("[%s] Saved WAIC to rds/waic_brms_constrained.rds\n", Sys.time()))
cat(sprintf("[%s] Done!\n", Sys.time()))
