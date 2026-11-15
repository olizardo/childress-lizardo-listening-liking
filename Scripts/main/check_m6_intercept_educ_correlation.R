#' @title Model 6: genre intercepts against genre education slopes
#' @description Education counterpart to Figure 7. Figure 7 pairs each genre's
#'   random intercept in the overclaiming equation with its random arts slope and
#'   finds them inversely related, which is the scarcity reading. This script
#'   computes the same pair for education, using Model 6, whose genre random
#'   effects carry arts exposure and education together.
#'
#'   The raw random intercept sits at educ2 = 0, far below the lowest observed
#'   category, and education enters the same random-effect block, so the raw
#'   intercept and the education slope are mechanically coupled. The reported
#'   intercept is therefore evaluated at the sample's mean education
#'   (u0 + total education slope * 3.26552), and the raw-intercept correlation is
#'   kept alongside as a check on how much the recentring matters.
#'
#'   Outputs: cache/m6_intercept_educ_genre.csv (per-genre posterior medians and
#'   95% bounds for the mean-education intercept and the total education slope,
#'   with the College Preference Ratio), and
#'   cache/m6_intercept_educ_correlation.csv (draw-level Pearson and Spearman
#'   correlations with medians, bounds and the share of draws below zero).

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(tidybayes)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

# Person-level mean of educ2 in dta/analysis_model_input.dta (1,450 respondents).
mean_educ <- 3.265517

cat("Loading M6 fit (arts and education slopes in the genre random effects)...\n")
fit <- readRDS("rds/model_brms_m6_educslopes.rds")
prest <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col)

tb <- fit |>
  spread_draws(b_muLikeOnly_educ2, r_genre_id__muLikeOnly[genre_id, term]) |>
  mutate(genre_id = as.character(genre_id)) |>
  pivot_wider(names_from = term, values_from = r_genre_id__muLikeOnly) |>
  mutate(
    genre_name = genre_names[genre_id],
    total_educ = b_muLikeOnly_educ2 + educ2,
    u0_mean_educ = Intercept + total_educ * mean_educ
  )

stopifnot(!any(is.na(tb$total_educ)), n_distinct(tb$genre_name) == 20)

cor_draws <- tb |>
  group_by(.draw) |>
  summarize(
    pearson_mean_educ = cor(u0_mean_educ, total_educ, method = "pearson"),
    spearman_mean_educ = cor(u0_mean_educ, total_educ, method = "spearman"),
    pearson_raw = cor(Intercept, total_educ, method = "pearson"),
    spearman_raw = cor(Intercept, total_educ, method = "spearman"),
    .groups = "drop"
  )

summarize_cor <- function(x) {
  data.frame(
    Median = as.numeric(median(x)),
    CrI_2.5 = as.numeric(quantile(x, 0.025)),
    CrI_97.5 = as.numeric(quantile(x, 0.975)),
    P_below_zero = as.numeric(mean(x < 0))
  )
}

cor_sets <- list(
  "Intercept at mean education vs. education slope (Pearson)" = cor_draws$pearson_mean_educ,
  "Intercept at mean education vs. education slope (Spearman)" = cor_draws$spearman_mean_educ,
  "Raw intercept vs. education slope (Pearson)" = cor_draws$pearson_raw,
  "Raw intercept vs. education slope (Spearman)" = cor_draws$spearman_raw
)

cor_report <- bind_rows(lapply(names(cor_sets), function(nm) {
  cbind(Statistic = nm, summarize_cor(cor_sets[[nm]]))
}))
cor_report[, -1] <- lapply(cor_report[, -1], function(x) round(as.numeric(x), 3))

genre_summary <- tb |>
  group_by(genre_name) |>
  summarize(
    u0_med = median(u0_mean_educ),
    u0_lo = as.numeric(quantile(u0_mean_educ, 0.025)),
    u0_hi = as.numeric(quantile(u0_mean_educ, 0.975)),
    educ_slope_med = median(total_educ),
    educ_slope_lo = as.numeric(quantile(total_educ, 0.025)),
    educ_slope_hi = as.numeric(quantile(total_educ, 0.975)),
    u0_raw_med = median(Intercept),
    .groups = "drop"
  ) |>
  left_join(prest, by = "genre_name")

stopifnot(nrow(genre_summary) == 20, !any(is.na(genre_summary$ratio_col)))

dir.create("cache", showWarnings = FALSE)
write.csv(genre_summary, "cache/m6_intercept_educ_genre.csv", row.names = FALSE)
write.csv(cor_report, "cache/m6_intercept_educ_correlation.csv", row.names = FALSE)

cat("\n===== DRAW-LEVEL CORRELATIONS ACROSS THE 20 GENRES =====\n")
print(cor_report)
cat("\nPoint-estimate correlations (medians): Pearson",
    round(cor(genre_summary$u0_med, genre_summary$educ_slope_med), 3),
    " Spearman", round(cor(genre_summary$u0_med, genre_summary$educ_slope_med, method = "spearman"), 3), "\n")
cat("\nPer-genre summary:\n")
print(as.data.frame(genre_summary |> arrange(u0_med) |>
                      select(genre_name, u0_med, educ_slope_med, ratio_col)))
