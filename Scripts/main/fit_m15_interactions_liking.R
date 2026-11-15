#' @title Bayesian Categorical Model, Prestige Interactions on the Liking States Only (Model 15)
#' @description Model 14 with the two prestige interactions removed from the
#'   underclaiming equation. Model 14 adds child_arts * prestige_c and
#'   educ2 * prestige_c to all three equations; underclaiming is 2.4% of dyads,
#'   has no credibly positive genre education slope, and its education slope at
#'   mean prestige is essentially zero, so both interaction coefficients in that
#'   equation are candidate dead weight. Dropping them leaves a model nested in
#'   Model 14, and the paired WAIC difference says whether they earn their keep.
#'
#'   prestige (College Preference Ratio) is genre-level and constant within
#'   genre and enters centered as prestige_c. Sampling settings follow Model 6
#'   (adapt_delta 0.98, max_treedepth 14).
#'
#'   Output: rds/model_brms_m15_interactions_liking.rds,
#'   rds/waic_m15_interactions_liking.rds, cache/diagnostics_m15.txt,
#'   cache/interactions_liking_test.csv

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

# Model 11 random structure (80 slopes), interactions on the two liking equations
bf_int_liking <- bf(
  engagement_state ~ 1,
  muListenOnly ~ educ2 + parent_educ + child_arts + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 | genre_id),
  muLikeOnly ~ child_arts * prestige_c + educ2 * prestige_c + parent_educ + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 + child_arts + educ2 | genre_id),
  muBoth ~ child_arts * prestige_c + educ2 * prestige_c + parent_educ + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 + child_arts + educ2 | genre_id)
)

priors_int_liking <- c(
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

cat("Sampling Model 15 (prestige interactions on the liking states only) via cmdstanr...\n")
fit <- brm(
  formula = bf_int_liking,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_int_liking,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 2489,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.98, max_treedepth = 14),
  file = "rds/model_brms_m15_interactions_liking",
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m15.txt")
cat("== Model 15 (prestige interactions on overclaiming and consistent engagement only), corrected data ==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 14), "\n")
sink()
cat(readLines("cache/diagnostics_m15.txt"), sep = "\n")

# Which exposure does prestige moderate, net of the other?
# Each interaction is per unit of the centered College Preference Ratio.
dr <- as_draws_df(fit)
rng_p <- diff(range(prest$ratio_col))

rows <- lapply(c("muLikeOnly", "muBoth"), function(st) {
  bind_rows(lapply(c("child_arts", "educ2"), function(v) {
    b_int <- dr[[paste0("b_", st, "_", v, ":prestige_c")]]
    b_main <- dr[[paste0("b_", st, "_", v)]]
    data.frame(
      State = gsub("^mu", "", st),
      Moderator = v,
      slope_at_mean_prestige = round(mean(b_main), 3),
      interaction = round(mean(b_int), 3),
      int_CrI_2.5 = round(quantile(b_int, 0.025), 3),
      int_CrI_97.5 = round(quantile(b_int, 0.975), 3),
      p_interaction = round(2 * min(mean(b_int <= 0), mean(b_int >= 0)), 4),
      # multiplicative change in the exposure effect across the observed
      # prestige range, from the same posterior draws
      multiplier_across_prestige_range = round(exp(mean(b_int) * rng_p), 3)
    )
  }))
})

m15 <- bind_rows(rows)
write.csv(m15, "cache/interactions_liking_test.csv", row.names = FALSE)
cat("\n===== PRESTIGE INTERACTIONS ON THE LIKING STATES (Model 15) =====\n")
print(m15)
cat("Saved cache/interactions_liking_test.csv\n")

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m15_interactions_liking.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m15_interactions_liking.rds")
cat("Done: rds/model_brms_m15_interactions_liking.rds\n")
