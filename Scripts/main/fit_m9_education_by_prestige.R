#' @title Bayesian Categorical Model, Education Effect Ordered by Genre Prestige (Model 9)
#' @description Model-level companion to Figure 9. Figure 9 correlates the
#'   genre education slopes extracted from Model 6 with the College Preference
#'   Ratio after the fact; this fit puts the ratio inside the likelihood as a
#'   fixed effect on the education slope, so the claim that education orders
#'   the genre hierarchy of overclaiming becomes a single coefficient with a
#'   posterior probability attached.
#'
#'   prestige (College Preference Ratio) is genre-level and constant within
#'   genre, so it cannot carry a random slope of its own and a random
#'   intercept for it would be absorbed. It enters centered as
#'   educ2 * prestige_c. The interaction coefficient is invariant to centering
#'   or rescaling educ2, so the education term is left on its natural 1-6
#'   scale (set levels only, no recentering). Random structure is exactly
#'   Model 6's, so the fixed interaction only absorbs the part of the
#'   education-slope heterogeneity that follows the prestige ordering.
#'   Sampling settings follow Model 6 (adapt_delta 0.98, max_treedepth 14).
#'
#'   Caveat to carry into prose: the College Preference Ratio is itself built
#'   from an education contrast, so this test is not fully independent of the
#'   education variable it orders by. Its value is that the interaction is now
#'   estimated inside the likelihood with all other covariates held fixed,
#'   rather than reassembled from extracted slopes.
#'
#'   Output: rds/model_brms_m9_educprestige.rds, rds/waic_m9_educprestige.rds,
#'   cache/diagnostics_m9.txt, cache/educ_prestige_test.csv

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

cat("Loading corrected model input...\n")
df_long <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    id = as.factor(id),
    genre_id = as.factor(genre_id),
    genre_name = genre_names[as.character(genre_id)],
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
stopifnot(!any(is.na(df_long$genre_name)))

# Educational prestige: College Preference Ratio, P(likes | BA+) / P(likes | HS or less)
prest <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col)
stopifnot(nrow(prest) == 20)

p_mean <- mean(prest$ratio_col)
prest <- prest |> mutate(prestige_c = ratio_col - p_mean)

df_long <- df_long |>
  left_join(prest |> select(genre_name, prestige_c), by = "genre_name")
stopifnot(!any(is.na(df_long$prestige_c)))

cat("Prestige (College Preference Ratio): mean", round(p_mean, 3),
    "| range", paste(round(range(prest$ratio_col), 2), collapse = " to "), "\n")
cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

# Model 6 random structure + fixed education-by-prestige interaction
bf_educ_prest <- bf(
  engagement_state ~ educ2 * prestige_c + parent_educ + child_arts + agecat + female +
    income + race5 + platform +
    (1 | id) +
    (1 + child_arts + educ2 | genre_id)
)

priors_educ_prest <- c(
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

cat("Sampling Model 9 (education effect ordered by prestige) via cmdstanr...\n")
fit <- brm(
  formula = bf_educ_prest,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_educ_prest,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 8714,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.98, max_treedepth = 14),
  file = "rds/model_brms_m9_educprestige",
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m9.txt")
cat("== Model 9 (education effect ordered by genre prestige), corrected data ==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 14), "\n")
sink()
cat(readLines("cache/diagnostics_m9.txt"), sep = "\n")

# Does the education gradient rise with genre prestige?
# educ2 spans levels 1-6, so 5 units is the full observed range used in Figure 9.
dr <- as_draws_df(fit)
rng_p <- diff(range(prest$ratio_col))
educ_step <- 5

m9 <- bind_rows(lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(s) {
  b_educ <- dr[[paste0("b_", s, "_educ2")]]
  b_int  <- dr[[paste0("b_", s, "_educ2:prestige_c")]]
  data.frame(
    State = gsub("^mu", "", s),
    educ_slope_at_mean_prestige = round(mean(b_educ), 3),
    interaction = round(mean(b_int), 3),
    int_CrI_2.5 = round(quantile(b_int, 0.025), 3),
    int_CrI_97.5 = round(quantile(b_int, 0.975), 3),
    p_interaction = round(2 * min(mean(b_int <= 0), mean(b_int >= 0)), 4),
    # odds ratio for the full education range at mean prestige and at the
    # lowest/highest observed prestige, from the same posterior draws
    OR_educ_fullrange_mean_prest = round(mean(exp(b_educ * educ_step)), 3),
    OR_educ_fullrange_min_prest = round(
      mean(exp((b_educ + b_int * (min(prest$ratio_col) - p_mean)) * educ_step)), 3),
    OR_educ_fullrange_max_prest = round(
      mean(exp((b_educ + b_int * (max(prest$ratio_col) - p_mean)) * educ_step)), 3),
    OR_multiplier_across_prestige_range = round(exp(mean(b_int) * rng_p), 3)
  )
}))
write.csv(m9, "cache/educ_prestige_test.csv", row.names = FALSE)
cat("\n===== EDUCATION EFFECT BY GENRE PRESTIGE (Figure 9 as a model test) =====\n")
print(m9)
cat("Saved cache/educ_prestige_test.csv\n")

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m9_educprestige.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m9_educprestige.rds")
cat("Done: rds/model_brms_m9_educprestige.rds\n")
