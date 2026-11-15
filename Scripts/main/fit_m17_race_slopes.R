#' @title Bayesian Categorical Model, Race-Specific Genre Slopes (Model 17)
#' @description Model 1 (baseline) plus two genre-level random slopes on single
#'   race dummies: the Black coefficient in the overclaiming (LikeOnly) equation
#'   and the Hispanic coefficient in the underclaiming (ListenOnly) equation.
#'   Fixed effects, priors and sampling settings otherwise follow
#'   fit_m1_baseline.R; the per-equation shape follows fit_m11 so the baseline
#'   1.5 fixed-effect prior reaches all three equations.
#'   Output: rds/model_brms_m17_race_slopes.rds + rds/waic_m17_race_slopes.rds

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)

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
# Categorical predictors as factors, matching the other corrected fits
# (bug fix 2026-11-12 in the M1-M5 scripts).
df_long$race5 <- factor(as.integer(df_long$race5), levels = 1:5,
                        labels = c("White", "Black", "Hispanic", "Asian", "Other/Mixed"))
df_long$platform <- factor(as.integer(df_long$platform), levels = 1:5,
                           labels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other"))

# Single-level dummies for the two random slopes. The race5 factor stays in the
# fixed part unchanged, so these enter the model only as genre-level slopes.
df_long$black_d <- as.integer(df_long$race5 == "Black")
df_long$hisp_d  <- as.integer(df_long$race5 == "Hispanic")

cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors
cat("Black respondents:", n_distinct(df_long$id[df_long$black_d == 1]),
    "| Hispanic respondents:", n_distinct(df_long$id[df_long$hisp_d == 1]), "\n")

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

# Baseline fixed effects everywhere; one genre slope in each of two equations.
bf_race_slopes <- bf(
  engagement_state ~ 1,
  muListenOnly ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
                 (1 | id) + (1 + hisp_d | genre_id),
  muLikeOnly   ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
                 (1 | id) + (1 + black_d | genre_id),
  muBoth       ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
                 (1 | id) + (1 | genre_id)
)

priors_race_slopes <- c(
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
dir.create("cache", showWarnings = FALSE)

cat("Sampling Model 17 (race-specific genre slopes) via cmdstanr...\n")
fit <- brm(
  formula = bf_race_slopes,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_race_slopes,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 5187,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.98, max_treedepth = 14),
  file = "rds/model_brms_m17_race_slopes",
  file_refit = "always"
)

print(summary(fit))

# Diagnostics snapshot for cache/diagnostics_m17.txt
sink("cache/diagnostics_m17.txt")
cat("== Model 17 (race-specific genre slopes), corrected data ==\n")
print(rhat(fit))
print(neff_ratio(fit))
cat("\nDivergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:",
    sum(nuts_params(fit, "treedepth__")$Value >= 14), "\n")
sink()

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m17_race_slopes.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m17_race_slopes.rds")
cat("Done: rds/model_brms_m17_race_slopes.rds\n")
