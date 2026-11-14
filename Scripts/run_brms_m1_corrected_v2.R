#' @title CORRECTED: Bayesian Categorical Random-Intercepts Model (Model 1, v2)
#' @description Baseline specification used by every table and figure in the
#'   manuscript. Identical to run_brms_m1_corrected.R except for the sampling
#'   settings, which were raised after the first corrected run (4000/1500,
#'   adapt_delta 0.97) showed thin effective sample sizes: iter 6000,
#'   warmup 2500, adapt_delta 0.995, max_treedepth 13, seed 6113, 14,000 kept
#'   draws per chain. Data come from dta/analysis_model_input.dta, built by
#'   Scripts/prep_model_input.R.
#'   Output: rds/model_brms_m1_corrected_v2.rds + rds/waic_m1_corrected_v2.rds

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
df_long$engagement_state <- factor(
  as.integer(df_long$engagement_state),
  levels = 1:4,
  labels = c("Neither", "ListenOnly", "LikeOnly", "Both")
)
# Categorical predictors entered as factors (matching the legacy run_brms.R
# specification); bug fix 2026-11-12 -- race5 and platform previously entered
# as numeric codes in the corrected fits.
df_long$race5 <- factor(as.integer(df_long$race5), levels = 1:5,
                        labels = c("White", "Black", "Hispanic", "Asian", "Other/Mixed"))
df_long$platform <- factor(as.integer(df_long$platform), levels = 1:5,
                           labels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other"))

cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

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

cat("Sampling Model 1 (corrected, v2 settings) via cmdstanr...\n")
fit <- brm(
  formula = bf_intercepts,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_intercepts,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 6000,
  warmup = 2500,
  control = list(adapt_delta = 0.995, max_treedepth = 13),
  backend = "cmdstanr",
  file = "rds/model_brms_m1_corrected_v2",
  file_refit = "always",
  seed = 6113
)

print(summary(fit))

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m1_corrected_v2.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m1_corrected_v2.rds")
cat("Done: rds/model_brms_m1_corrected_v2.rds\n")
