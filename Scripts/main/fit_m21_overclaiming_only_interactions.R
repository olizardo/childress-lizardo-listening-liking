#' @title Bayesian Categorical Model, Overclaiming-Only Interactions (Model 21)
#' @description Model 11's restricted random structure (arts and education fixed
#'   effects in all three active equations, random arts and education slopes
#'   only in the liking equations, 80 slopes) with both genre-level interactions
#'   confined to the overclaiming equation: child_arts x popularity_c and
#'   educ2 x prestige_c enter muLikeOnly only. The other two equations carry the
#'   two capital indicators without their moderators.
#'
#'   This is the model the interaction results point to. Models 19 and 20 both
#'   find arts x popularity credible only in overclaiming and the education
#'   interaction credible in every state, but neither says whether the
#'   non-overclaiming terms are needed. Model 21 drops them, so it is nested in
#'   Model 19 (which carries both interactions in all three equations) and the
#'   paired WAIC asks exactly that question. It stays nested in Model 11 too.
#'
#'   Moderators are genre-level, constant within genre, and enter centered, so
#'   their main effects would be collinear with the genre random intercepts;
#'   they appear only through the interactions, which are therefore centered on
#'   the genre mean of each moderator. Sampling settings follow Model 6
#'   (adapt_delta 0.98, max_treedepth 14).
#'
#'   Output: rds/model_brms_m21_oc_only.rds, rds/waic_m21_oc_only.rds,
#'   cache/diagnostics_m21.txt, cache/overclaiming_only_interactions.csv,
#'   cache/overclaiming_only_waic.csv

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

# Model 11 random structure (80 slopes); the two interactions live in the
# overclaiming equation only.
bf_oc_only <- bf(
  engagement_state ~ 1,
  muListenOnly ~ child_arts + educ2 + parent_educ + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 | genre_id),
  muLikeOnly ~ child_arts * popularity_c + educ2 * prestige_c +
    parent_educ + agecat + female + income + race5 + platform +
    (1 | id) + (1 + child_arts + educ2 | genre_id),
  muBoth ~ child_arts + educ2 + parent_educ + agecat + female +
    income + race5 + platform +
    (1 | id) + (1 + child_arts + educ2 | genre_id)
)

priors_oc_only <- c(
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

cat("Sampling Model 21 (overclaiming-only interactions, restricted slopes) via cmdstanr...\n")
fit <- brm(
  formula = bf_oc_only,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_oc_only,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 4000,
  warmup = 1500,
  seed = 5147,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.98, max_treedepth = 14),
  file = "rds/model_brms_m21_oc_only",
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m21.txt")
cat("== Model 21 (arts x popularity and education x prestige, overclaiming equation only) ==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 14), "\n")
sink()
cat(readLines("cache/diagnostics_m21.txt"), sep = "\n")

# ------------------------------------------------------------- the two terms
# brms orders interaction names by variable position in the formula, so try
# both orders. Only the overclaiming equation carries interactions here.
dr <- as_draws_df(fit)
rng_prest <- diff(range(prest$ratio_col))
rng_pop <- diff(range(pop$pop_med))

pick <- function(cands) {
  hit <- cands[cands %in% names(dr)]
  if (length(hit) != 1) stop("expected exactly one of: ", paste(cands, collapse = ", "))
  as.numeric(dr[[hit]])
}

specs <- list(
  list(v = "child_arts", m = "popularity_c", rng = rng_pop,
       ename = "arts", mname = "popularity"),
  list(v = "educ2", m = "prestige_c", rng = rng_prest,
       ename = "education", mname = "prestige (CPR)")
)

m21 <- bind_rows(lapply(specs, function(spec) {
  b_int <- pick(c(paste0("b_muLikeOnly_", spec$v, ":", spec$m),
                  paste0("b_muLikeOnly_", spec$m, ":", spec$v)))
  b_main <- pick(paste0("b_muLikeOnly_", spec$v))
  data.frame(
    State = "LikeOnly",
    Exposure = spec$ename,
    Moderator = spec$mname,
    slope_at_mean_moderator = round(mean(b_main), 3),
    interaction = round(mean(b_int), 3),
    int_CrI_2.5 = round(quantile(b_int, 0.025), 3),
    int_CrI_97.5 = round(quantile(b_int, 0.975), 3),
    p_interaction = round(2 * min(mean(b_int <= 0), mean(b_int >= 0)), 4),
    multiplier_across_moderator_range = round(exp(mean(b_int) * spec$rng), 3)
  )
}))

write.csv(m21, "cache/overclaiming_only_interactions.csv", row.names = FALSE)
cat("\n===== OVERCLAIMING-ONLY INTERACTIONS (Model 21) =====\n")
print(m21)
cat("Saved cache/overclaiming_only_interactions.csv\n")

# ------------------------------------------------------- paired WAIC vs others
cat("\nComputing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m21_oc_only.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m21_oc_only.rds")

refs <- c(
  "M1 baseline" = "rds/waic_m1_corrected_v2.rds",
  "M11"         = "rds/waic_m11_educarts_liking.rds",
  "M14"         = "rds/waic_m14_both_mods_restricted.rds",
  "M19"         = "rds/waic_m19_poparts_eduprestige.rds",
  "M20"         = "rds/waic_m20_full_cross.rds"
)

elpd_m21 <- waic_res$pointwise[, "elpd_waic"]
stopifnot(nrow(waic_res$pointwise) == nrow(df_long))

cmp <- bind_rows(lapply(names(refs), function(nm) {
  f <- refs[[nm]]
  if (!file.exists(f)) return(data.frame(Comparison = paste("M21 vs", nm), note = "file missing"))
  w <- readRDS(f)
  if (nrow(w$pointwise) != length(elpd_m21)) {
    return(data.frame(Comparison = paste("M21 vs", nm), note = "row count mismatch"))
  }
  d <- elpd_m21 - w$pointwise[, "elpd_waic"]
  est <- sum(d)
  se <- sd(d) * sqrt(length(d))
  data.frame(
    Comparison = paste("M21 vs", nm),
    delta_elpd = round(est, 1),
    se = round(se, 1),
    p_bayes = round(2 * pnorm(-abs(est / se)), 4),
    note = ""
  )
}))

write.csv(cmp, "cache/overclaiming_only_waic.csv", row.names = FALSE)
cat("\n===== WAIC: Model 21 AGAINST THE OTHER FITS =====\n")
print(cmp)
cat("Saved cache/overclaiming_only_waic.csv\n")
cat("Done: rds/model_brms_m21_oc_only.rds\n")
