#' @title Robustness Check: Platform Small-Cell Sensitivity (Winamp N=10)
#' @description Adapted to the corrected pipeline (2026-11-13). Refits the
#'   baseline crossed random-intercepts specification (Model 1) on the
#'   corrected model input twice more -- (a) dropping Winamp respondents
#'   entirely, and (b) collapsing Winamp into "Other" -- and compares the
#'   key child_arts coefficients against rds/model_brms_m1_corrected_v2.rds.
#'   Sampling settings match the corrected M1 v2 fit (iter 6000 /
#'   warmup 2500, adapt_delta 0.995).
#'   Output: rds/model_robustness_no_winamp_corrected.rds,
#'   rds/model_robustness_winamp_collapsed_corrected.rds,
#'   cache/robustness_platform.csv
#'
#'   Memory discipline (2026-11-14): the 2026-11-13 run requested 3 GB and was
#'   OOM-killed at the comparison step, with two variant fits and the baseline
#'   all in memory at once. Each fit is now extracted and dropped before the
#'   next one is loaded or fitted, so peak memory is a single brmsfit. Fits are
#'   still persisted by brm(file = ...), so a rerun reuses whatever already
#'   exists on disk.

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading corrected model input...\n")
df_long_full <- read_dta("dta/analysis_model_input.dta") |>
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

cat("Sample size:", nrow(df_long_full), "rows across", n_distinct(df_long_full$id), "respondents.\n")
stopifnot(is.factor(df_long_full$race5), is.factor(df_long_full$platform))  # response coding guard: race5/platform must be factors
cat("Winamp respondents in sample:", n_distinct(df_long_full$id[df_long_full$platform == "Winamp"]), "\n")

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

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

fit_one <- function(data, platform_levels, out_file, seed) {
  data <- data %>%
    mutate(platform = factor(as.character(platform), levels = platform_levels))
  bf_intercepts <- bf(
    engagement_state ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
      (1 | id) + (1 | genre_id)
  )
  brm(
    formula = bf_intercepts,
    data = data,
    family = categorical(link = "logit", refcat = "Neither"),
    prior = priors_intercepts,
    chains = n_chains,
    cores = n_chains,
    threads = threading(threads_per_chain),
    iter = 6000,
    warmup = 2500,
    control = list(adapt_delta = 0.995, max_treedepth = 13),
    backend = "cmdstanr",
    file = out_file,
    file_refit = "on_change",
    seed = seed
  )
}

dir.create("rds", showWarnings = FALSE)
dir.create("cache", showWarnings = FALSE)

extract_child_arts <- function(fit, label) {
  draws <- brms::as_draws_df(fit)
  states <- c("muListenOnly", "muLikeOnly", "muBoth")
  rows <- lapply(states, function(s) {
    col <- paste0("b_", s, "_child_arts")
    if (!col %in% names(draws)) return(NULL)
    x <- draws[[col]]
    data.frame(
      Specification = label,
      State = gsub("^mu", "", s),
      Mean = round(mean(x), 3),
      SD = round(sd(x), 3),
      CrI_2.5 = round(quantile(x, 0.025), 3),
      CrI_97.5 = round(quantile(x, 0.975), 3),
      p_bayes = 2 * min(mean(x <= 0), mean(x >= 0))
    )
  })
  bind_rows(rows)
}

# Load one fit at a time, extract, release: peak memory is a single brmsfit.
extract_child_arts_from_file <- function(path, label) {
  cat(sprintf("[%s] Extracting %s from %s ...\n", Sys.time(), label, path))
  stopifnot(file.exists(path))
  fit <- readRDS(path)
  out <- extract_child_arts(fit, label)
  rm(fit)
  gc()
  out
}


cat("Fitting variant (a): dropping Winamp respondents entirely...\n")
df_no_winamp <- df_long_full %>% filter(platform != "Winamp")
fit_no_winamp <- fit_one(
  df_no_winamp,
  platform_levels = c("Free Recall", "Spotify", "iTunes", "Other"),
  out_file = "rds/model_robustness_no_winamp_corrected",
  seed = 7714
)
stopifnot(file.exists("rds/model_robustness_no_winamp_corrected.rds"))
res_no_winamp <- extract_child_arts(fit_no_winamp, "Winamp dropped")
rm(fit_no_winamp)
gc()

cat("Fitting variant (b): collapsing Winamp into Other...\n")
df_collapsed <- df_long_full %>%
  mutate(platform = ifelse(platform == "Winamp", "Other", as.character(platform)))
fit_collapsed <- fit_one(
  df_collapsed,
  platform_levels = c("Free Recall", "Spotify", "iTunes", "Other"),
  out_file = "rds/model_robustness_winamp_collapsed_corrected",
  seed = 9042
)
stopifnot(file.exists("rds/model_robustness_winamp_collapsed_corrected.rds"))
res_collapsed <- extract_child_arts(fit_collapsed, "Winamp collapsed into Other")
rm(fit_collapsed)
gc()

comparison <- bind_rows(
  extract_child_arts_from_file("rds/model_brms_m1_corrected_v2.rds",
                               "Corrected M1 v2 (Winamp included, N=10)"),
  res_no_winamp,
  res_collapsed
)

write.csv(comparison, "cache/robustness_platform.csv", row.names = FALSE)
cat("\n===== CHILD_ARTS COEFFICIENT COMPARISON ACROSS PLATFORM SPECIFICATIONS =====\n")
print(comparison)
cat("=============================================================================\n")
cat("Saved to cache/robustness_platform.csv\n")
