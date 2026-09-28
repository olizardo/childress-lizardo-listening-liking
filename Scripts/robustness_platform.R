#' @title Robustness Check: Platform Small-Cell Sensitivity (Winamp N=10)
#' @description The Winamp platform category contains only 10 respondents
#'   but receives its own fixed-effect dummy in every model. This script
#'   refits the baseline crossed random-intercepts specification (Model 1)
#'   twice more -- (a) dropping Winamp respondents entirely, and (b)
#'   collapsing Winamp into "Other" -- and compares the key child_arts
#'   coefficients against the original Model 1 fit to check whether the
#'   headline arts-exposure effects are sensitive to this small cell.

options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("brms", quietly = TRUE)) install.packages("brms")
if (!requireNamespace("cmdstanr", quietly = TRUE)) install.packages("cmdstanr", repos = c("https://mc-stan.org/r-packages/", getOption("repos")))
if (!requireNamespace("haven", quietly = TRUE)) install.packages("haven")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr")

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)
library(tidyr)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading and processing data for Platform Robustness Check...\n")
df_raw <- read_dta("dta/analysis_time_CCC.dta")
df_raw$id <- 1:nrow(df_raw)

genre_mapping <- list(
  g1=21, g2=22, g3=24, g4=39, g5=26, g6=36, g7=37, g8=23, g9=31, g10=27,
  g11=28, g12=40, g13=29, g14=30, g15=25, g16=32, g17=38, g18=33, g19=34, g20=35
)

for (g in 1:20) {
  like_col <- paste0("like_music_genres_", genre_mapping[[paste0("g", g)]])
  df_raw[[paste0("like_g", g)]] <- ifelse(df_raw[[like_col]] >= 5 & df_raw[[like_col]] <= 7, 1, 0)

  df_raw[[paste0("listen_g", g)]] <- 0
  for (i in 1:10) {
    df_raw[[paste0("listen_g", g)]] <- df_raw[[paste0("listen_g", g)]] | (df_raw[[paste0("genre_final", i)]] == g)
  }
}

df_long_full <- df_raw %>%
  mutate(
    parent_educ = pmax(mom_educ, dad_educ, na.rm = TRUE),
    platform = case_when(
      grepl("spotify", stream_source, ignore.case = TRUE) ~ "Spotify",
      grepl("itunes", stream_source, ignore.case = TRUE) ~ "iTunes",
      grepl("winamp", stream_source, ignore.case = TRUE) ~ "Winamp",
      grepl("rotation", stream_source, ignore.case = TRUE) & !grepl("itunes|spotify|winamp", stream_source, ignore.case = TRUE) ~ "Free Recall",
      stream_source == "" ~ "Free Recall",
      TRUE ~ "Other"
    )
  ) %>%
  select(id, educ2, parent_educ, child_arts, agecat, female, income, race5, platform,
         starts_with("like_g"), starts_with("listen_g")) %>%
  pivot_longer(
    cols = matches("^(like|listen)_g\\d+"),
    names_to = c(".value", "genre_id"),
    names_pattern = "^([a-z]+)_g(\\d+)$"
  ) %>%
  mutate(
    id = as.factor(id),
    genre_id = as.factor(genre_id),
    race5 = as.factor(race5),
    engagement_state = case_when(
      like == 0 & listen == 0 ~ "Neither",
      like == 0 & listen == 1 ~ "ListenOnly",
      like == 1 & listen == 0 ~ "LikeOnly",
      like == 1 & listen == 1 ~ "Both"
    ),
    engagement_state = factor(engagement_state, levels = c("Neither", "ListenOnly", "LikeOnly", "Both"))
  ) %>%
  filter(
    !is.na(engagement_state),
    !is.na(educ2),
    !is.na(parent_educ),
    !is.na(child_arts),
    !is.na(agecat),
    !is.na(female),
    !is.na(income),
    !is.na(race5),
    !is.na(platform)
  )

cat("Full cleaned sample:", nrow(df_long_full), "rows across", n_distinct(df_long_full$id), "respondents.\n")
cat("Winamp respondents in sample:", n_distinct(df_long_full$id[df_long_full$platform == "Winamp"]), "\n")

n_slots <- as.integer(Sys.getenv("NSLOTS", unset = 16))
n_chains <- 4
threads_per_chain <- max(1, floor(n_slots / n_chains))

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
    mutate(platform = factor(platform, levels = platform_levels))
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
    iter = 2000,
    warmup = 1000,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    backend = "cmdstanr",
    file = out_file,
    file_refit = "on_change",
    seed = seed
  )
}

dir.create("rds", showWarnings = FALSE)
dir.create("cache", showWarnings = FALSE)

cat("Fitting variant (a): dropping Winamp respondents entirely...\n")
df_no_winamp <- df_long_full %>% filter(platform != "Winamp")
fit_no_winamp <- fit_one(
  df_no_winamp,
  platform_levels = c("Free Recall", "Spotify", "iTunes", "Other"),
  out_file = "rds/model_robustness_no_winamp",
  seed = 7714
)

cat("Fitting variant (b): collapsing Winamp into Other...\n")
df_collapsed <- df_long_full %>%
  mutate(platform = ifelse(platform == "Winamp", "Other", platform))
fit_collapsed <- fit_one(
  df_collapsed,
  platform_levels = c("Free Recall", "Spotify", "iTunes", "Other"),
  out_file = "rds/model_robustness_winamp_collapsed",
  seed = 9042
)

cat("Loading original baseline fit for comparison...\n")
fit_original <- readRDS("rds/model_brms_intercepts.rds")

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
      CrI_97.5 = round(quantile(x, 0.975), 3)
    )
  })
  bind_rows(rows)
}

comparison <- bind_rows(
  extract_child_arts(fit_original, "Original (Winamp included, N=10)"),
  extract_child_arts(fit_no_winamp, "Winamp dropped"),
  extract_child_arts(fit_collapsed, "Winamp collapsed into Other")
)

write.csv(comparison, "cache/robustness_platform.csv", row.names = FALSE)
cat("\n===== CHILD_ARTS COEFFICIENT COMPARISON ACROSS PLATFORM SPECIFICATIONS =====\n")
print(comparison)
cat("=============================================================================\n")
cat("Saved to cache/robustness_platform.csv\n")
