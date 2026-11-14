#' @title Model 6: education-by-genre slopes against educational prestige (H3A/H3B)
#' @description Post-processing for the education-slopes fit
#'   rds/model_brms_m6_educslopes.rds, whose genre random effects are
#'   (1 + child_arts + educ2 | genre_id). Model 6 asks whether a second
#'   indicator of cultural capital, education, produces the same genre-level
#'   ordering as childhood arts exposure. For each posterior draw this script
#'   computes, across the twenty genres, the correlation between the
#'   genre-specific total education slope for overclaiming and the genre's
#'   educational prestige (College Preference Ratio), and the same correlation
#'   for the genre-specific arts slope inside the same model. It also reports
#'   how closely the two sets of genre slopes agree with each other.
#'
#'   Output: cache/m6_educ_prestige_correlations.csv,
#'           cache/m6_educ_genre_slopes.csv

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(dplyr)
  library(tidyr)
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

cat("Loading M6 fit...\n")
fit <- readRDS("rds/model_brms_m6_educslopes.rds")
prest <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col, ratio_black)

tb <- fit |>
  spread_draws(
    b_muLikeOnly_educ2,
    b_muLikeOnly_child_arts,
    r_genre_id__muLikeOnly[genre_id, term]
  ) |>
  mutate(genre_id = as.character(genre_id)) |>
  pivot_wider(names_from = term, values_from = r_genre_id__muLikeOnly) |>
  mutate(
    genre_name = genre_names[genre_id],
    total_educ = b_muLikeOnly_educ2 + educ2,
    total_arts = b_muLikeOnly_child_arts + child_arts
  )

stopifnot(!any(is.na(tb$total_educ)), n_distinct(tb$genre_name) == 20)

draw_level <- tb |>
  left_join(prest, by = "genre_name")
stopifnot(nrow(draw_level) == nrow(tb))

cor_draws <- draw_level |>
  group_by(.draw) |>
  summarise(
    educ_prestige_pearson = cor(total_educ, ratio_col, method = "pearson"),
    educ_prestige_spearman = cor(total_educ, ratio_col, method = "spearman"),
    arts_prestige_pearson = cor(total_arts, ratio_col, method = "pearson"),
    educ_arts_pearson = cor(total_educ, total_arts, method = "pearson"),
    .groups = "drop"
  )

summarise_stat <- function(x, label) {
  data.frame(
    Statistic = label,
    Median = round(median(x), 3),
    CrI_2.5 = round(quantile(x, 0.025), 3),
    CrI_97.5 = round(quantile(x, 0.975), 3),
    p_bayes = round(2 * min(mean(x <= 0), mean(x >= 0)), 4)
  )
}

report <- bind_rows(
  summarise_stat(cor_draws$educ_prestige_pearson, "Pearson r (education slope vs prestige)"),
  summarise_stat(cor_draws$educ_prestige_spearman, "Spearman rho (education slope vs prestige)"),
  summarise_stat(cor_draws$arts_prestige_pearson, "Pearson r (arts slope vs prestige, same fit)"),
  summarise_stat(cor_draws$educ_arts_pearson, "Pearson r (education slope vs arts slope)")
)

dir.create("cache", showWarnings = FALSE)
write.csv(report, "cache/m6_educ_prestige_correlations.csv", row.names = FALSE)
cat("\n===== M6 GENRE-LEVEL CORRELATIONS =====\n")
print(report)

genre_out <- draw_level |>
  group_by(genre_name) |>
  summarise(
    educ_slope_med = median(total_educ),
    educ_slope_lo = quantile(total_educ, 0.025),
    educ_slope_hi = quantile(total_educ, 0.975),
    arts_slope_med = median(total_arts),
    .groups = "drop"
  ) |>
  left_join(prest, by = "genre_name") |>
  mutate(
    educ_credibly_positive = educ_slope_lo > 0,
    educ_credibly_negative = educ_slope_hi < 0
  ) |>
  arrange(desc(ratio_col))

write.csv(genre_out, "cache/m6_educ_genre_slopes.csv", row.names = FALSE)
cat("\nGenres with a credibly positive education slope:",
    sum(genre_out$educ_credibly_positive), "of", nrow(genre_out), "\n")
cat("Genres with a credibly negative education slope:",
    sum(genre_out$educ_credibly_negative), "of", nrow(genre_out), "\n")
cat("Saved cache/m6_educ_genre_slopes.csv\n")
