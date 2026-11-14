#' @title Bayesian Categorical Model, Arts Effect Moderated by Prestige and Popularity (Model 12)
#' @description Model 8 with a second genre-level moderator added, so the two
#'   competing accounts of where the arts effect is largest enter the likelihood
#'   together. Model 8 finds the arts x College Preference Ratio interaction
#'   credible in the overclaiming equation, but the ratio is correlated with
#'   genre popularity, so this model asks which attribute carries the moderation:
#'   child_arts * prestige_c, child_arts * pop_c, or both.
#'
#'   Popularity is the share of person-genre dyads in which the respondent
#'   actually listened to an artist in the genre (ListenOnly + Both), taken from
#'   the model input. That measure comes from the playlist side and so does not
#'   reuse the stated-liking indicator that defines overclaiming. Set
#'   POP_MEASURE <- "liked" to rerun with the stated-liking share instead; the
#'   output files carry the measure in their names, so the two variants do not
#'   overwrite each other.
#'
#'   Both moderators are genre-level constants, so neither can carry a random
#'   slope of its own; both enter centered, and the genre random slopes are
#'   retained, which means the interactions capture only the part of the slope
#'   heterogeneity that follows each ordering. Sampling settings follow Model 8.
#'
#'   Output: rds/model_brms_m12_arts_mods_<measure>.rds,
#'   rds/waic_m12_arts_mods_<measure>.rds, cache/diagnostics_m12.txt,
#'   cache/arts_prestige_popularity_test_<measure>.csv

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)

POP_MEASURE <- "listened"   # "listened" (playlist share) or "liked" (stated-liking share)

stopifnot(POP_MEASURE %in% c("listened", "liked"))

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

# Genre popularity from the same dyad file, so every genre gets exactly one value
pop <- df_long |>
  group_by(genre_name) |>
  summarise(
    pop_raw = if (POP_MEASURE == "listened") {
      mean(as.integer(engagement_state) %in% c(2, 4))
    } else {
      mean(as.integer(engagement_state) %in% c(3, 4))
    },
    .groups = "drop"
  )
stopifnot(nrow(pop) == 20)

p_mean <- mean(prest$ratio_col)
pop_mean <- mean(pop$pop_raw)
mods <- prest |>
  left_join(pop, by = "genre_name") |>
  mutate(prestige_c = ratio_col - p_mean,
         pop_c = pop_raw - pop_mean)
stopifnot(!any(is.na(mods$pop_c)), nrow(mods) == 20)

df_long <- df_long |>
  left_join(mods |> select(genre_name, prestige_c, pop_c), by = "genre_name")
stopifnot(!any(is.na(df_long$prestige_c)), !any(is.na(df_long$pop_c)))

cat("Preference ratio: mean", round(p_mean, 3),
    "| range", paste(round(range(mods$ratio_col), 2), collapse = " to "), "\n")
cat("Popularity (", POP_MEASURE, "): mean", round(pop_mean, 3),
    "| range", paste(round(range(mods$pop_raw), 2), collapse = " to "), "\n")
cat("Correlation between the two moderators:", round(cor(mods$prestige_c, mods$pop_c), 3), "\n")
cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

bf_two_mods <- bf(
  engagement_state ~ educ2 + parent_educ + child_arts * (prestige_c + pop_c) + agecat +
    female + income + race5 + platform +
    (1 | id) +
    (1 + child_arts | genre_id)
)

priors_two_mods <- c(
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

fit_stem <- paste0("rds/model_brms_m12_arts_mods_", POP_MEASURE)
cat("Sampling Model 12 (arts effect moderated by prestige and popularity:", POP_MEASURE, ") via cmdstanr...\n")
fit <- brm(
  formula = bf_two_mods,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_two_mods,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 5087,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.97, max_treedepth = 13),
  file = fit_stem,
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m12.txt")
cat("== Model 12 (arts effect moderated by prestige and popularity), measure:", POP_MEASURE, "==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 13), "\n")
sink()
cat(readLines("cache/diagnostics_m12.txt"), sep = "\n")

# Which moderator carries the arts-effect heterogeneity?
dr <- as_draws_df(fit)
rng_prest <- diff(range(mods$ratio_col))
rng_pop   <- diff(range(mods$pop_raw))
two <- bind_rows(lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(s) {
  b_arts <- dr[[paste0("b_", s, "_child_arts")]]
  b_prest <- dr[[paste0("b_", s, "_child_arts:prestige_c")]]
  b_pop   <- dr[[paste0("b_", s, "_child_arts:pop_c")]]
  data.frame(
    State = gsub("^mu", "", s),
    arts_at_mean_mods = round(mean(b_arts), 3),
    int_prestige = round(mean(b_prest), 3),
    int_prestige_CrI_2.5 = round(quantile(b_prest, 0.025), 3),
    int_prestige_CrI_97.5 = round(quantile(b_prest, 0.975), 3),
    p_prestige = round(2 * min(mean(b_prest <= 0), mean(b_prest >= 0)), 4),
    OR_prestige_full_range = round(exp(mean(b_prest) * rng_prest), 3),
    int_popularity = round(mean(b_pop), 3),
    int_popularity_CrI_2.5 = round(quantile(b_pop, 0.025), 3),
    int_popularity_CrI_97.5 = round(quantile(b_pop, 0.975), 3),
    p_popularity = round(2 * min(mean(b_pop <= 0), mean(b_pop >= 0)), 4),
    OR_popularity_full_range = round(exp(mean(b_pop) * rng_pop), 3)
  )
}))
out_csv <- paste0("cache/arts_prestige_popularity_test_", POP_MEASURE, ".csv")
write.csv(two, out_csv, row.names = FALSE)
cat("\n===== ARTS EFFECT: PRESTIGE VERSUS POPULARITY (", POP_MEASURE, ") =====\n")
print(two)
cat("Saved", out_csv, "\n")

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, paste0("rds/waic_m12_arts_mods_", POP_MEASURE, ".rds"))
fit$criteria$waic <- waic_res
saveRDS(fit, paste0(fit_stem, ".rds"))
cat("Done:", paste0(fit_stem, ".rds"), "\n")
