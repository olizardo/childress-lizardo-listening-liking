#' @title Bayesian Categorical Model, Education-Only Random Slopes (Model 16)
#' @description Reference fit for the reduced model table: random intercepts for
#'   respondents and genres plus education-by-genre random slopes, with the arts
#'   exposure effect held constant across genres. This is the education-side
#'   counterpart of Model 5 and the baseline against which Model 6 and Model 9
#'   separate the two exposures.
#'   Mirrors fit_m6_education_slopes.R (corrected data, same priors and sampling
#'   settings) with child_arts dropped from the genre random effect.
#'   Output: rds/model_brms_m16_educslopes_only.rds + rds/waic_m16_educslopes_only.rds

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

cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

# Random intercepts plus education-only genre random slopes
bf_educ_only <- bf(
  engagement_state ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
    (1 | id) +
    (1 + educ2 | genre_id)
)

priors_educ_only <- c(
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

cat("Sampling Model 16 (education random slopes only, all three equations) via cmdstanr...\n")
fit <- brm(
  formula = bf_educ_only,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_educ_only,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 8821,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.98, max_treedepth = 14),
  file = "rds/model_brms_m16_educslopes_only",
  file_refit = "always"
)

print(summary(fit))

# Diagnostics snapshot for cache/diagnostics_m16.txt
sink("cache/diagnostics_m16.txt")
cat("== Model 16 (education-only genre random slopes), corrected data ==\n")
print(rhat(fit))
print(neff_ratio(fit))
cat("\nDivergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:",
    sum(nuts_params(fit, "treedepth__")$Value >= 14), "\n")
sink()

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m16_educslopes_only.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m16_educslopes_only.rds")
cat("Done: rds/model_brms_m16_educslopes_only.rds\n")
