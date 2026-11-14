# Unconditional (covariate-averaged) prevalences of the four engagement states
# from the local M1 v2 fit. One fit per process, isolated Rscript on the cluster.

library(brms)
library(data.table)

fit <- readRDS("rds/model_brms_m1_corrected_v2.rds")

# Thin to 2000 evenly spaced draws to keep memory and time manageable
draws_idx <- round(seq(1, ndraws(fit), length.out = 2000))

pe <- posterior_epred(
  fit,
  summary = FALSE,
  ndraws = length(draws_idx),
  draw_ids = draws_idx
)
# pe: draws x 28655 x 4 (categories in factor level order of engagement_state)
dim(pe)

# Average over all dyads within each draw -> posterior of overall prevalence
prev <- apply(pe, c(1, 3), mean)
colnames(prev) <- levels(fit$data$engagement_state)

# Observed shares for comparison
dat <- fit$data
obs <- prop.table(table(dat$engagement_state))

out <- data.frame(
  state = colnames(prev),
  observed_share = as.numeric(obs[match(colnames(prev), names(obs))]),
  posterior_mean = colMeans(prev),
  ci_low = apply(prev, 2, quantile, 0.025),
  ci_high = apply(prev, 2, quantile, 0.975)
)
fwrite(out, "cache/state_prevalences_marginal_m1.csv")
print(out)
cat("done\n")
