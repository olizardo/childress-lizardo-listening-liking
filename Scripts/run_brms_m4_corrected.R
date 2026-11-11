#' @title CORRECTED: Bayesian Categorical Model, Slopes on LikeOnly + Both (Model 4)
#' @description Model 4 (preferred specification) refit on the corrected data.
#'   Changes relative to run_brms_constrained_over_true_refit.R:
#'   (1) Data from dta/analysis_model_input.dta (rebuilt genre_final, NA-safe
#'       listening; see Scripts/prep_model_input.R).
#'   (2) save_pars(all = TRUE) dropped; default pars (fixed effects, random
#'       effects, correlations) suffice for all downstream table/figure scripts.
#'   Output: rds/model_brms_m4_corrected.rds + rds/waic_m4_corrected.rds

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)
library(tidyr)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading corrected model input...\n")
df_long <- read_dta("dta/analysis_model_input.dta")
df_long$id <- as.factor(df_long$id)
df_long$genre_id <- as.factor(df_long$genre_id)

cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

bf_over_true <- bf(
  engagement_state ~ 1,
  muListenOnly ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
                 (1 | id) + (1 | genre_id),
  muLikeOnly   ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
                 (1 | id) + (1 + child_arts | genre_id),
  muBoth       ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
                 (1 | id) + (1 + child_arts | genre_id)
)

priors_over_true <- c(
  prior(normal(0, 1.5), class = "b", dpar = "muListenOnly"),
  prior(normal(0, 1.5), class = "b", dpar = "muLikeOnly"),
  prior(normal(0, 1.5), class = "b", dpar = "muBoth"),
  prior(normal(0, 2), class = "Intercept", dpar = "muListenOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muLikeOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muBoth"),
  prior(exponential(1), class = "sd", dpar = "muListenOnly"),
  prior(exponential(1), class = "sd", dpar = "muLikeOnly"),
  prior(exponential(1), class = "sd", dpar = "muBoth"),
  prior(lkj(2), class = "cor")
)

dir.create("rds", showWarnings = FALSE)

cat("Sampling Model 4 (corrected) via cmdstanr...\n")
fit <- brm(
  formula = bf_over_true,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_over_true,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 4729,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.97, max_treedepth = 13),
  file = "rds/model_brms_m4_corrected",
  file_refit = "always"
)

print(summary(fit))

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m4_corrected.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m4_corrected.rds")
cat("Done: rds/model_brms_m4_corrected.rds\n")
