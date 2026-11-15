#' @title Model 11 genre random effects: everything Figures 5-10 need
#' @description Paper Model 3 is local Model 11 (Model 4's shape plus education
#'   on the same two equations). It replaces Model 4 for the arts figures and
#'   Model 6 for the education figures, so this script extracts in one pass
#'   every genre-level quantity those six figures use:
#'
#'   cache/m11_arts_slope_draws.csv      all draws of each genre's total arts
#'                                       slope for overclaiming (Figure 5 half-eyes)
#'   cache/m11_educ_slope_draws.csv      all draws of each genre's total education
#'                                       slope for overclaiming (Figure 6 half-eyes)
#'   cache/m11_genre_summary.csv         per genre: overclaiming random intercept,
#'                                       arts slope, education slope, odds ratios
#'                                       with 95% bounds, College Preference Ratio
#'                                       (Figures 7, 9 and the education overlay)
#'   cache/m11_correlations.csv          draw-level correlations: arts odds vs
#'                                       prestige, education slope vs prestige,
#'                                       arts slope vs racial ratio, intercept vs
#'                                       arts slope, education vs arts slope
#'   cache/m11_intercept_educ_genre.csv  intercept at mean education against the
#'                                       education slope (Figure 8)
#'   cache/m11_intercept_educ_correlation.csv  correlations behind Figure 8
#'
#'   Model 11 carries (1 + child_arts + educ2 | genre_id) in the overclaiming and
#'   consistent-engagement equations and (1 | genre_id) in the underclaiming
#'   equation, so the underclaiming equation has no slopes to extract.

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(dplyr)
  library(tidyr)
  library(posterior)
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

cat("Loading rds/model_brms_m11_educarts_liking.rds ...\n")
fit <- readRDS("rds/model_brms_m11_educarts_liking.rds")
prest <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col, ratio_black)
stopifnot(nrow(prest) == 20)

dr <- as_draws_matrix(fit)
cn <- colnames(dr)
n_draw <- nrow(dr)
cat("Draws:", n_draw, "\n")

# ---- Overclaiming genre effects, draw level -------------------------------
get_state <- function(st) {
  idx <- grep(paste0("^r_genre_id__", st, "\\["), cn)
  nm <- cn[idx]
  genre <- as.integer(sub(".*\\[([0-9]+),.*$", "\\1", nm))
  term <- sub(".*,([A-Za-z_0-9]+)\\]$", "\\1", nm)
  stopifnot(length(unique(genre)) == 20,
            setequal(unique(term), c("Intercept", "child_arts", "educ2")))
  out <- lapply(1:20, function(g) {
    data.frame(
      .draw = seq_len(n_draw),
      genre_id = g,
      u0 = as.numeric(dr[, idx[which(genre == g & term == "Intercept")]]),
      u1 = as.numeric(dr[, idx[which(genre == g & term == "child_arts")]]),
      ue = as.numeric(dr[, idx[which(genre == g & term == "educ2")]])
    )
  })
  bind_rows(out) |>
    mutate(
      genre_name = genre_names[as.character(genre_id)],
      arts_total = as.numeric(dr[, paste0("b_", st, "_child_arts")]) + u1,
      educ_total = as.numeric(dr[, paste0("b_", st, "_educ2")]) + ue
    )
}

cat("Extracting overclaiming genre effects...\n")
like <- get_state("muLikeOnly")
cat("Extracting consistent-engagement genre effects...\n")
both <- get_state("muBoth")

stopifnot(nrow(like) == n_draw * 20, !any(is.na(like$arts_total)),
          !any(is.na(like$educ_total)))

# ---- Draw-level files for the half-eye figures ----------------------------
write.csv(
  like |> select(.draw, genre_id, genre_name, total_arts = arts_total),
  "cache/m11_arts_slope_draws.csv", row.names = FALSE
)
write.csv(
  like |> select(.draw, genre_id, genre_name, total_educ = educ_total),
  "cache/m11_educ_slope_draws.csv", row.names = FALSE
)

# ---- Per-genre summary for Figures 7, 8, 9, 10 ----------------------------
q <- function(x, p) as.numeric(quantile(x, p))

genre_summary <- like |>
  group_by(genre_name) |>
  summarise(
    u0_med = q(u0, 0.5), u0_lo = q(u0, 0.025), u0_hi = q(u0, 0.975),
    u1_med = q(u1, 0.5), u1_lo = q(u1, 0.025), u1_hi = q(u1, 0.975),
    arts_slope_med = q(arts_total, 0.5),
    arts_slope_lo = q(arts_total, 0.025),
    arts_slope_hi = q(arts_total, 0.975),
    educ_slope_med = q(educ_total, 0.5),
    educ_slope_lo = q(educ_total, 0.025),
    educ_slope_hi = q(educ_total, 0.975),
    # Five-step arts contrast (levels 6-7 vs 1-2) and the six-step L7 vs L1 used
    # in Figures 7 and 9; four-step education contrast (categories 5-6 vs 1-2).
    or_med = q(exp(arts_total * 5), 0.5),
    or_lo = q(exp(arts_total * 5), 0.025),
    or_hi = q(exp(arts_total * 5), 0.975),
    or6_med = q(exp(arts_total * 6), 0.5),
    or6_lo = q(exp(arts_total * 6), 0.025),
    or6_hi = q(exp(arts_total * 6), 0.975),
    educ_or4_med = q(exp(educ_total * 4), 0.5),
    educ_or4_lo = q(exp(educ_total * 4), 0.025),
    educ_or4_hi = q(exp(educ_total * 4), 0.975),
    pd_above_1 = mean(exp(arts_total * 5) > 1),
    .groups = "drop"
  ) |>
  left_join(prest, by = "genre_name") |>
  mutate(
    cred_status = case_when(
      pd_above_1 >= 0.975 ~ "Credibly Increases Overclaiming",
      pd_above_1 <= 0.025 ~ "Credibly Decreases Overclaiming",
      TRUE ~ "Not Credible"
    ),
    pref_cat = case_when(
      ratio_col < 1.0 ~ "Less Preferred (< 1.0)",
      ratio_col >= 1.0 & ratio_col <= 1.25 ~ "Slightly Preferred (1.0 - 1.25)",
      ratio_col > 1.25 ~ "Preferred (> 1.25)"
    )
  )

stopifnot(nrow(genre_summary) == 20, !any(is.na(genre_summary$ratio_col)))
write.csv(genre_summary, "cache/m11_genre_summary.csv", row.names = FALSE)

# ---- Draw-level correlations ----------------------------------------------
cor_draws <- like |>
  left_join(prest, by = "genre_name") |>
  group_by(.draw) |>
  summarise(
    arts_prestige_pearson = cor(arts_total, ratio_col, method = "pearson"),
    arts_prestige_spearman = cor(arts_total, ratio_col, method = "spearman"),
    arts_racial_spearman = cor(arts_total, ratio_black, method = "spearman"),
    educ_prestige_pearson = cor(educ_total, ratio_col, method = "pearson"),
    educ_prestige_spearman = cor(educ_total, ratio_col, method = "spearman"),
    educ_arts_pearson = cor(educ_total, arts_total, method = "pearson"),
    u0_u1_pearson = cor(u0, u1, method = "pearson"),
    u0_u1_spearman = cor(u0, u1, method = "spearman"),
    .groups = "drop"
  )

summ <- function(x) {
  data.frame(Median = round(median(x), 3),
             CrI_2.5 = round(quantile(x, 0.025), 3),
             CrI_97.5 = round(quantile(x, 0.975), 3),
             p_bayes = round(2 * min(mean(x <= 0), mean(x >= 0)), 4))
}
cor_report <- bind_rows(lapply(names(cor_draws)[-1], function(nm) {
  cbind(Statistic = nm, summ(cor_draws[[nm]]))
}))
write.csv(cor_report, "cache/m11_correlations.csv", row.names = FALSE)

# ---- Intercept at mean education against the education slope (Figure 8) ----
tb8 <- like |>
  mutate(
    u0_mean_educ = u0 + educ_total * mean_educ
  ) |>
  left_join(prest, by = "genre_name")

cor8 <- tb8 |>
  group_by(.draw) |>
  summarise(
    pearson_mean_educ = cor(u0_mean_educ, educ_total, method = "pearson"),
    spearman_mean_educ = cor(u0_mean_educ, educ_total, method = "spearman"),
    pearson_raw = cor(u0, educ_total, method = "pearson"),
    spearman_raw = cor(u0, educ_total, method = "spearman"),
    .groups = "drop"
  )

cor8_report <- bind_rows(
  cbind(Statistic = "Intercept at mean education vs. education slope (Pearson)", summ(cor8$pearson_mean_educ)),
  cbind(Statistic = "Intercept at mean education vs. education slope (Spearman)", summ(cor8$spearman_mean_educ)),
  cbind(Statistic = "Raw intercept vs. education slope (Pearson)", summ(cor8$pearson_raw)),
  cbind(Statistic = "Raw intercept vs. education slope (Spearman)", summ(cor8$spearman_raw))
)
write.csv(cor8_report, "cache/m11_intercept_educ_correlation.csv", row.names = FALSE)

genre8 <- tb8 |>
  group_by(genre_name) |>
  summarise(
    u0_med = q(u0_mean_educ, 0.5), u0_lo = q(u0_mean_educ, 0.025), u0_hi = q(u0_mean_educ, 0.975),
    educ_slope_med = q(educ_total, 0.5), educ_slope_lo = q(educ_total, 0.025),
    educ_slope_hi = q(educ_total, 0.975),
    u0_raw_med = q(u0, 0.5),
    .groups = "drop"
  ) |>
  left_join(prest, by = "genre_name")
stopifnot(nrow(genre8) == 20, !any(is.na(genre8$ratio_col)))
write.csv(genre8, "cache/m11_intercept_educ_genre.csv", row.names = FALSE)

# ---- Consistent-engagement slopes by state (used by Figures 11 and 12) ------
state_lookup <- c("muLikeOnly" = "Overclaiming", "muBoth" = "Consistent Engagement")

by_state <- bind_rows(
  like |> mutate(State = "Overclaiming"),
  both |> mutate(State = "Consistent Engagement")
) |>
  group_by(State, genre_name) |>
  summarise(
    arts_slope_med = q(arts_total, 0.5), arts_slope_lo = q(arts_total, 0.025),
    arts_slope_hi = q(arts_total, 0.975),
    educ_slope_med = q(educ_total, 0.5), educ_slope_lo = q(educ_total, 0.025),
    educ_slope_hi = q(educ_total, 0.975),
    .groups = "drop"
  ) |>
  left_join(prest, by = "genre_name") |>
  arrange(State, desc(ratio_col))

write.csv(
  by_state |> select(State, genre_name, ratio_col, slope_med = arts_slope_med,
                     slope_lo = arts_slope_lo, slope_hi = arts_slope_hi),
  "cache/m11_arts_slope_by_state.csv", row.names = FALSE
)
write.csv(
  by_state |> select(State, genre_name, ratio_col, slope_med = educ_slope_med,
                     slope_lo = educ_slope_lo, slope_hi = educ_slope_hi),
  "cache/m11_educ_slope_by_state.csv", row.names = FALSE
)

# ---- Console summary ------------------------------------------------------
cat("\n===== M11 GENRE CORRELATIONS =====\n")
print(cor_report)
cat("\n===== FIGURE 8 CORRELATIONS =====\n")
print(cor8_report)
cat("\nArts odds ratios across genres (five-point contrast):\n")
print(genre_summary |> arrange(or_med) |>
        select(genre_name, or_med, or_lo, or_hi, cred_status) |> as.data.frame())
cat("\nGenres with a credibly positive education slope:",
    sum(genre_summary$educ_slope_lo > 0), "of 20\n")
cat("Genres with a credibly negative education slope:",
    sum(genre_summary$educ_slope_hi < 0), "of 20\n")
cat("\nSaved m11_arts_slope_draws, m11_educ_slope_draws, m11_genre_summary,\n")
cat("m11_correlations, m11_intercept_educ_genre, m11_intercept_educ_correlation,\n")
cat("m11_arts_slope_by_state, m11_educ_slope_by_state\n")
