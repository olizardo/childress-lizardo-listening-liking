#' @title CORRECTED: Bayesian Categorical Random-Intercepts Model (Model 1)
#' @description Model 1 refit on the corrected data. Two changes relative to
#'   run_brms_intercepts.R:
#'   (1) Data come from dta/analysis_model_input.dta, built by
#'       Scripts/prep_model_input.R: genre_final1-10 and stream_source come
#'       from the rebuilt (patch-free) genresobjects_processed.dta, and
#'       listening is coded NA-safe, removing the outcome-dependent sample
#'       selection in the old inline construction.
#'   (2) Sampling settings match the other refits (iter 4000, warmup 1500,
#'       adapt_delta 0.97, max_treedepth 13) for adequate ESS.
#'   Output: rds/model_brms_m1_corrected.rds + rds/waic_m1_corrected.rds

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

bf_intercepts <- bf(
  engagement_state ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
    (1 | id) +
    (1 | genre_id)
)

priors_intercepts <- c(
  prior(normal(0, 1.5), class = "b", dpar = "muListenOnly"),
  prior(normal(0, 1.5), class = "b", dpar = "muLikeOnly"),
  prior(normal(0, 1.5), class = "b", dpar = "muBoth"),
  prior(normal(0, 2), class = "Intercept", dpar = "muListenOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muLikeOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muBoth"),
  prior(exponential(1), class = "sd", dpar = "muListenOnly"),
  prior(exponential(1), class = "sd", dpar = "muLikeOnly"),
  prior(exponential(1), class = "sd", dpar = "muBoth")
)

dir.create("rds", showWarnings = FALSE)

cat("Sampling Model 1 (corrected) via cmdstanr...\n")
fit <- brm(
  formula = bf_intercepts,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_intercepts,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  control = list(adapt_delta = 0.97, max_treedepth = 13),
  backend = "cmdstanr",
  file = "rds/model_brms_m1_corrected",
  file_refit = "always",
  seed = 6113
)

print(summary(fit))

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m1_corrected.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m1_corrected.rds")
cat("Done: rds/model_brms_m1_corrected.rds\n")
