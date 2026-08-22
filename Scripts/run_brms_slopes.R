#' @title Fit Bayesian Categorical Random Slopes Model
#' @description Fits a crossed random-effects multinomial logistic regression
#'   model where the effect of childhood arts exposure varies randomly across genres
#'   using brms and cmdstanr on Hoffman2.

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

cat("Loading and processing data for Random Slopes model...\n")
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

df_long <- df_raw %>%
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
    platform = factor(platform, levels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other")),
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

cat("Cleaned sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")

# Cores and threading setup
n_slots <- as.integer(Sys.getenv("NSLOTS", unset = 16))
n_chains <- 4
threads_per_chain <- max(1, floor(n_slots / n_chains))

cat("Sampling configuration:\n")
cat(" - Allocated slots:", n_slots, "\n")
cat(" - Chains:", n_chains, "\n")
cat(" - Threads per chain:", threads_per_chain, "\n")

# Crossed Random Intercepts + Random Slopes for child_arts by genre
bf_slopes <- bf(
  engagement_state ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
    (1 | id) +
    (1 + child_arts | genre_id)
)

# Regularizing Weakly Informative Priors
priors_slopes <- c(
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

cat("Starting brms Random Slopes sampling via cmdstanr...\n")
fit_brms_slopes <- brm(
  formula = bf_slopes,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_slopes,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 2000,
  warmup = 1000,
  control = list(adapt_delta = 0.90, max_treedepth = 12),
  backend = "cmdstanr",
  file = "rds/model_brms_slopes",
  file_refit = "on_change",
  seed = 42
)

cat("Random Slopes model sampling complete and saved to rds/model_brms_slopes.rds!\n")
