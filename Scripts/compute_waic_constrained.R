#' @title Compute WAIC for Constrained LikeOnly Slopes Model on Hoffman2
library(brms)

cat("Loading constrained model from rds/model_brms_constrained_likeonly.rds...\n")
fit <- readRDS("rds/model_brms_constrained_likeonly.rds")

cat("Computing WAIC...\n")
fit_waic <- add_criterion(fit, "waic", cores = 4)

cat("Saving updated model with WAIC criterion...\n")
saveRDS(fit_waic, "rds/model_brms_constrained_likeonly.rds")

# Print summary
print(fit_waic$criteria$waic)
cat("WAIC computation complete!\n")
