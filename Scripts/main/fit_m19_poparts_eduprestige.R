#' @title Bayesian Categorical Model, Matched Moderators (Model 19)
#' @description Model 11's restricted random structure (arts and education
#'   slopes only in the overclaiming and consistent-engagement equations, random
#'   intercepts only for underclaiming, 80 slopes) with one moderator per
#'   capital indicator: child_arts interacts with genre popularity and educ2
#'   interacts with the College Preference Ratio. No cross terms, so each
#'   moderator is tied to its own capital indicator by design. Contrasts of
#'   interest, all paired against M11's WAIC object: M19 vs M11 tests whether
#'   the matched interactions help; M19 vs M14 tests whether the symmetric
#'   both-moderators version beats the matched one.
#'
#'   popularity is the model-based genre popularity from the baseline fit
#'   (one minus the fitted Neither share averaged over each genre's rows;
#'   cache/m1_genre_popularity.csv). Both moderators are genre-level and
#'   constant within genre and enter centered (popularity_c, prestige_c); as
#'   main effects they are collinear with the genre random intercepts and are
#'   carried only so the interactions are centered on their means. Both
#'   interactions are written on the natural scale of their exposure variable.
#'   Sampling settings follow Model 6 (adapt_delta 0.98, max_treedepth 14).
#'
#'   Output: rds/model_brms_m19_poparts_eduprestige.rds,
#'   rds/waic_m19_poparts_eduprestige.rds, cache/diagnostics_m19.txt,
#'   cache/matched_moderators_test.csv

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

# Genre popularity from the baseline fit (post_m1_genre_popularity.R)
pop <- read.csv("cache/m1_genre_popularity.csv") |>
  select(genre_name, pop_med)
stopifnot(nrow(pop) == 20)

pop_mean <- mean(pop$pop_med)
pop <- pop |> mutate(popularity_c = pop_med - pop_mean)

df_long <- df_long |>
  left_join(prest |> select(genre_name, prestige_c), by = "genre_name") |>
  left_join(pop |> select(genre_name, popularity_c), by = "genre_name")
stopifnot(!any(is.na(df_long$prestige_c)), !any(is.na(df_long$popularity_c)))

cat("Prestige (College Preference Ratio): mean", round(p_mean, 3),
    "| range", paste(round(range(prest$ratio_col), 2), collapse = " to "), "\n")
cat("Popularity: mean", round(pop_mean, 3),
    "| range", paste(round(range(pop$pop_med), 2), collapse = " to "), "\n")
cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

# Model 11 random structure (80 slopes) + matched interactions:
# child_arts x popularity_c and educ2 x prestige_c, no cross terms
bf_matched_mods <- bf(
  engagement_state ~ 1,
  muListenOnly ~ child_arts * popularity_c + educ2 * prestige_c + parent_educ + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 | genre_id),
  muLikeOnly ~ child_arts * popularity_c + educ2 * prestige_c + parent_educ + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 + child_arts + educ2 | genre_id),
  muBoth ~ child_arts * popularity_c + educ2 * prestige_c + parent_educ + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 + child_arts + educ2 | genre_id)
)

priors_matched_mods <- c(
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

cat("Sampling Model 19 (matched interactions, restricted slopes) via cmdstanr...\n")
fit <- brm(
  formula = bf_matched_mods,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_matched_mods,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 4217,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.98, max_treedepth = 14),
  file = "rds/model_brms_m19_poparts_eduprestige",
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m19.txt")
cat("== Model 19 (arts x popularity, education x prestige, restricted 80-slope structure) ==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 14), "\n")
sink()
cat(readLines("cache/diagnostics_m19.txt"), sep = "\n")

# Which moderator pairs with which exposure, in which equation?
# Each interaction is per unit of the centered moderator.
# brms orders interaction names by variable position in the formula, so try both orders.
dr <- as_draws_df(fit)
rng_prest <- diff(range(prest$ratio_col))
rng_pop <- diff(range(pop$pop_med))

rows <- lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(st) {
  bind_rows(lapply(
    list(list(v = "child_arts", m = "popularity_c", rng = rng_pop,
              mname = "popularity"),
         list(v = "educ2", m = "prestige_c", rng = rng_prest,
              mname = "prestige (CPR)")),
    function(spec) {
      v <- spec$v; m <- spec$m
      cand <- c(paste0("b_", st, "_", v, ":", m),
                paste0("b_", st, "_", m, ":", v))
      cand <- cand[cand %in% names(dr)]
      if (!length(cand)) stop("no interaction column for ", st, ": ", v, " x ", m)
      b_int <- dr[[cand[1]]]
      b_main <- dr[[paste0("b_", st, "_", v)]]
      data.frame(
        State = gsub("^mu", "", st),
        Exposure = v,
        Moderator = spec$mname,
        slope_at_mean_moderator = round(mean(b_main), 3),
        interaction = round(mean(b_int), 3),
        int_CrI_2.5 = round(quantile(b_int, 0.025), 3),
        int_CrI_97.5 = round(quantile(b_int, 0.975), 3),
        p_interaction = round(2 * min(mean(b_int <= 0), mean(b_int >= 0)), 4),
        # multiplicative change in the exposure effect across the observed
        # moderator range, from the same posterior draws
        multiplier_across_moderator_range = round(exp(mean(b_int) * spec$rng), 3)
      )
    }
  ))
})

m19 <- bind_rows(rows)
write.csv(m19, "cache/matched_moderators_test.csv", row.names = FALSE)
cat("\n===== MATCHED MODERATORS: ARTS x POPULARITY, EDUCATION x PRESTIGE (Model 19) =====\n")
print(m19)
cat("Saved cache/matched_moderators_test.csv\n")

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m19_poparts_eduprestige.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m19_poparts_eduprestige.rds")
cat("Done: rds/model_brms_m19_poparts_eduprestige.rds\n")
