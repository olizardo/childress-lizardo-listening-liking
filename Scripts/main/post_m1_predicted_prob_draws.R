#' @title Draw-level predicted state probabilities by childhood arts exposure
#' @description Cluster-side extraction for the posterior-distribution companion
#'   to Figure 3. Same quantity as figure_3_predicted_probs.R: for each arts
#'   level 1-7, every person-genre row gets its child_arts value replaced
#'   (person and genre effects held at their estimates), posterior_epred draws
#'   are averaged within draw across all rows. The 1,000 draws are kept rather
#'   than collapsed to median and 95% bounds.
#'
#'   Runs on Hoffman2 because posterior_epred materialises ~1 GB arrays at each
#'   of the seven levels; running it locally froze a 14 GB machine.
#'
#'   Output: cache/childarts_predicted_probs_draws.csv.gz with columns
#'   child_arts, state, prob (1,000 rows per level-state cell).

suppressMessages({
  library(cmdstanr)
  library(brms)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")
set.seed(6197)

cat("Loading rds/model_brms_m1_corrected_v2.rds ...\n")
fit <- readRDS("rds/model_brms_m1_corrected_v2.rds")

nd_base <- fit$data
states <- levels(nd_base$engagement_state)
stopifnot(states[1] == "Neither")
cat("Rows:", nrow(nd_base), "| states:", paste(states, collapse = ", "), "\n")

ndraws <- 1000
results <- vector("list", 7)
for (L in 1:7) {
  cat(sprintf("Arts level %d...\n", L))
  nd <- nd_base
  nd$child_arts <- L
  ep <- posterior_epred(fit, newdata = nd, ndraws = ndraws, summary = FALSE)
  cat("  ep dims:", paste(dim(ep), collapse = " x "), "\n")
  if (dim(ep)[1] == ndraws) {
    arr <- ep
  } else if (dim(ep)[3] == ndraws) {
    arr <- aperm(ep, c(3, 1, 2))
  } else {
    stop("unexpected posterior_epred dimensions")
  }
  state_mean <- apply(arr, c(1, 3), mean)
  colnames(state_mean) <- states
  results[[L]] <- data.frame(
    child_arts = L,
    state = rep(states, each = ndraws),
    prob = as.vector(state_mean)
  )
  rm(ep, arr, state_mean)
  gc()
}

draws_df <- do.call(rbind, results)
stopifnot(nrow(draws_df) == 7 * ndraws * length(states))

dir.create("cache", showWarnings = FALSE)
gz <- gzfile("cache/childarts_predicted_probs_draws.csv.gz", "w")
write.csv(draws_df, gz, row.names = FALSE)
close(gz)

cat("Wrote cache/childarts_predicted_probs_draws.csv.gz (", nrow(draws_df), "rows )\n")

# Sanity check against the medians already in the Figure 3 cache file
old <- read.csv("cache/childarts_predicted_probs.csv")
chk <- aggregate(prob ~ child_arts + state, data = draws_df, FUN = median)
m <- merge(chk, old, by = c("child_arts", "state"), suffixes = c("_new", "_rep3"))
stopifnot(nrow(m) == 28, all(c("prob", "median") %in% names(m)))
m$diff <- m$prob - m$median
cat("Max |median difference| vs Figure 3 cache:", max(abs(m$diff)), "\n")
print(m[order(-abs(m$diff)), ][1:4, ])
