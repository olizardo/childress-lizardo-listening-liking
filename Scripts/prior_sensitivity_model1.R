#' @title Prior Sensitivity Check: Wider Fixed-Effect Prior (Model 1 only)
#' @description Adapted to the corrected pipeline (2026-11-13). Refits the
#'   baseline crossed random-intercepts model on the corrected model input
#'   with a wider fixed-effect prior (normal(0, 3) instead of normal(0, 1.5))
#'   and compares the headline child_arts coefficients against
#'   rds/model_brms_m1_corrected_v2.rds. Sampling settings match the
#'   corrected M1 v2 fit (iter 6000 / warmup 2500, adapt_delta 0.995).
#'   Output: rds/model_brms_m1_wideprior_corrected.rds +
#'   cache/prior_sensitivity_model1.csv

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading corrected model input...\n")
df_long <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    id = as.factor(id),
    genre_id = as.factor(genre_id),
    engagement_state = factor(
      as.integer(engagement_state),
      levels = 1:4,
      labels = c("Neither", "ListenOnly", "LikeOnly", "Both")
    ),
    race5 = factor(
      as.integer(race5),
      levels = 1:5,
      labels = c("White", "Black", "Hispanic", "Asian", "Other/Mixed")
    ),
    platform = factor(
      as.integer(platform),
      levels = 1:5,
      labels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other")
    )
  )

cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

bf_intercepts <- bf(
  engagement_state ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
    (1 | id) + (1 | genre_id)
)

priors_wide <- c(
  prior(normal(0, 3), class = "b", dpar = "muListenOnly"),
  prior(normal(0, 3), class = "b", dpar = "muLikeOnly"),
  prior(normal(0, 3), class = "b", dpar = "muBoth"),
  prior(normal(0, 2), class = "Intercept", dpar = "muListenOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muLikeOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muBoth"),
  prior(exponential(1), class = "sd", dpar = "muListenOnly"),
  prior(exponential(1), class = "sd", dpar = "muLikeOnly"),
  prior(exponential(1), class = "sd", dpar = "muBoth")
)

dir.create("rds", showWarnings = FALSE)
dir.create("cache", showWarnings = FALSE)

cat("Fitting corrected Model 1 with widened fixed-effect prior normal(0,3)...\n")
fit_wide <- brm(
  formula = bf_intercepts,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_wide,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 6000,
  warmup = 2500,
  control = list(adapt_delta = 0.995, max_treedepth = 13),
  backend = "cmdstanr",
  file = "rds/model_brms_m1_wideprior_corrected",
  file_refit = "on_change",
  seed = 15556
)

cat("Loading corrected Model 1 v2 fit for comparison...\n")
fit_orig <- readRDS("rds/model_brms_m1_corrected_v2.rds")

extract_child_arts <- function(fit, label) {
  draws <- brms::as_draws_df(fit)
  states <- c("muListenOnly", "muLikeOnly", "muBoth")
  rows <- lapply(states, function(s) {
    col <- paste0("b_", s, "_child_arts")
    x <- draws[[col]]
    data.frame(
      Specification = label, State = gsub("^mu", "", s),
      Mean = round(mean(x), 3), SD = round(sd(x), 3),
      CrI_2.5 = round(quantile(x, 0.025), 3), CrI_97.5 = round(quantile(x, 0.975), 3),
      p_bayes = 2 * min(mean(x <= 0), mean(x >= 0))
    )
  })
  bind_rows(rows)
}

comparison <- bind_rows(
  extract_child_arts(fit_orig, "Corrected M1 v2: normal(0, 1.5)"),
  extract_child_arts(fit_wide, "Wider prior: normal(0, 3)")
)

write.csv(comparison, "cache/prior_sensitivity_model1.csv", row.names = FALSE)
cat("\n===== CHILD_ARTS COEFFICIENT COMPARISON ACROSS FIXED-EFFECT PRIOR WIDTH =====\n")
print(comparison)
cat("Saved to cache/prior_sensitivity_model1.csv\n")
