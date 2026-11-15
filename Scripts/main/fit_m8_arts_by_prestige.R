#' @title Bayesian Categorical Model, Arts Effect Ordered by Genre Prestige (Model 8)
#' @description Model-level test of H3A versus H3B. Instead of correlating
#'   extracted genre slopes with prestige after the fact (the descriptive
#'   companion in Figure 8 and cache/correlation_draws_summary.csv), this
#'   model puts prestige inside the likelihood as a fixed effect on the arts
#'   slope, so the highbrow-versus-lowbrow contrast is a single coefficient
#'   with a posterior probability attached.
#'
#'   prestige is genre-level and constant within genre (so it cannot carry a
#'   random slope of its own, and a random intercept for it would just be
#'   absorbed). It enters centered, as child_arts * prestige_c, giving the
#'   linear arts term at mean prestige and an interaction that says how much
#'   steeper the arts effect is in a genre one unit higher in prestige. A
#'   positive interaction supports H3A (arts exposure amplifies overclaiming
#'   most in consecrated genres); a negative one supports H3B.
#'
#'   The genre random slopes are retained, so prestige_c captures only the
#'   part of the slope heterogeneity that follows the prestige ordering.
#'   Specification otherwise matches Model 4/M5 (crossed random slopes on
#'   child_arts, corrected data). Sampling settings follow M5.
#'
#'   Output: rds/model_brms_m8_prestigeslopes.rds, rds/waic_m8_prestigeslopes.rds,
#'   cache/diagnostics_m8.txt, cache/prestige_slope_test.csv

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

bf_prest <- bf(
  engagement_state ~ educ2 + parent_educ + child_arts * prestige_c + agecat + female +
    income + race5 + platform +
    (1 | id) +
    (1 + child_arts | genre_id)
)

priors_prest <- c(
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

cat("Sampling Model 8 (arts effect ordered by prestige) via cmdstanr...\n")
fit <- brm(
  formula = bf_prest,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_prest,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 2759,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.97, max_treedepth = 13),
  file = "rds/model_brms_m8_prestigeslopes",
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m8.txt")
cat("== Model 8 (arts effect ordered by genre prestige), corrected data ==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 13), "\n")
sink()
cat(readLines("cache/diagnostics_m8.txt"), sep = "\n")

# H3A versus H3B: sign and credibility of the arts x prestige interaction
dr <- as_draws_df(fit)
rng <- diff(range(prest$ratio_col))
h3 <- bind_rows(lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(s) {
  b_arts <- dr[[paste0("b_", s, "_child_arts")]]
  b_int  <- dr[[paste0("b_", s, "_child_arts:prestige_c")]]
  # OR change per one-unit rise in the prestige ratio, and across its full range
  data.frame(
    State = gsub("^mu", "", s),
    arts_at_mean_prestige = round(mean(b_arts), 3),
    interaction = round(mean(b_int), 3),
    int_CrI_2.5 = round(quantile(b_int, 0.025), 3),
    int_CrI_97.5 = round(quantile(b_int, 0.975), 3),
    p_interaction = round(2 * min(mean(b_int <= 0), mean(b_int >= 0)), 4),
    OR_per_unit_prestige = round(exp(mean(b_int)), 3),
    OR_full_range = round(exp(mean(b_int) * rng), 3)
  )
}))
write.csv(h3, "cache/prestige_slope_test.csv", row.names = FALSE)
cat("\n===== H3A/H3B: ARTS EFFECT BY GENRE PRESTIGE =====\n")
print(h3)
cat("Saved cache/prestige_slope_test.csv\n")

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m8_prestigeslopes.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m8_prestigeslopes.rds")
cat("Done: rds/model_brms_m8_prestigeslopes.rds\n")
