#' @title Figure 14: genre-specific Black coefficient in the overclaiming equation
#' @description Same idiom as Figures 5 and 6 (half-eye of the per-genre odds
#'   ratio against 1), for the race slope instead of the arts or education
#'   slope. Sourced from Model 17 through cache/m17_genre_race_slope_draws.csv
#'   written by post_m17_race_slopes.R. Reads no fit, so it rebuilds in seconds.
#'
#'   The race contrast is binary (Black versus White respondents), so the odds
#'   ratio is exp(slope) with no multiplier, unlike the five-point arts contrast
#'   in Figure 5 and the four-point education contrast in Figure 6.
#'
#'   Overclaiming only: the Hispanic underclaiming slope from the same fit is
#'   omitted because its random-slope SD is 0.11 and no genre resolves, so the
#'   panel carries no signal.
#'
#'   Outputs: Plots/fig14_race_genre_odds.png,
#'            cache/race_odds_by_genre.csv

library(dplyr)
library(ggplot2)
library(ggdist)

cat("Reading Model 17 race slope draws...\n")
draws <- read.csv("cache/m17_genre_race_slope_draws.csv", stringsAsFactors = FALSE)
stopifnot(n_distinct(draws$genre_name) == 20, !any(is.na(draws$odds_ratio)),
          all(c("Overclaiming", "Underclaiming") %in% draws$State))

state_labels <- c(
  "Overclaiming"  = "Overclaiming (Like Only vs. Neither)",
  "Underclaiming" = "Underclaiming (Listen Only vs. Neither)"
)

cred_summary <- draws |>
  group_by(State, genre_name) |>
  summarise(
    pd_above_1 = mean(odds_ratio > 1),
    q2.5 = quantile(odds_ratio, 0.025),
    median = median(odds_ratio),
    q97.5 = quantile(odds_ratio, 0.975),
    .groups = "drop"
  ) |>
  mutate(
    cred_status = case_when(
      pd_above_1 >= 0.975 ~ "Credibly Above 1",
      pd_above_1 <= 0.025 ~ "Credibly Below 1",
      TRUE ~ "Not Credible"
    ),
    State = factor(state_labels[State], levels = state_labels)
  )
write.csv(cred_summary, "cache/race_odds_by_genre.csv", row.names = FALSE)

# Genre order is set within state, after the summary, because dplyr joins drop
# factor levels.
draws <- draws |>
  mutate(State = factor(state_labels[State], levels = state_labels)) |>
  left_join(cred_summary |> select(State, genre_name, cred_status),
            by = c("State", "genre_name"))

cred_colors <- c(
  "Credibly Above 1" = "#0072B2",
  "Credibly Below 1" = "#D55E00",
  "Not Credible"     = "gray60"
)

# Black respondents, overclaiming equation only.
draws_black <- draws |> filter(State == "Overclaiming (Like Only vs. Neither)")

p <- ggplot(draws_black, aes(x = odds_ratio, y = reorder(genre_name, odds_ratio, median),
                             fill = cred_status, color = cred_status)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray45", linewidth = 0.75) +
  stat_halfeye(
    point_interval = ggdist::median_qi,
    .width = 0.95,
    point_size = 3.5,
    interval_size = 1.2,
    slab_alpha = 0.35,
    scale = 0.7
  ) +
  scale_fill_manual(values = cred_colors, name = "Directional Credibility") +
  scale_color_manual(values = cred_colors, name = "Directional Credibility") +
  scale_x_log10() +
  labs(
    title = "Genre-Specific Black Coefficient in the Overclaiming Equation",
    subtitle = paste0(
      "Odds ratios for Black relative to White respondents (Like Only vs. Neither).\n",
      "The contrast is binary, so the odds ratio is exp(slope), with no exposure multiplier."
    ),
    x = "Odds Ratio Relative to White Respondents",
    y = NULL,
    caption = paste0(
      "Model 17 adds a genre random slope on the Black dummy to the overclaiming equation, on the corrected\n",
      "baseline otherwise. Points are posterior medians; bars are 95% credible intervals. Color rule:\n",
      "pd >= 0.975 of the odds ratio exceeding 1, matching the plotted two-sided intervals. Log x-axis."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13.5, margin = margin(b = 5)),
    plot.subtitle = element_text(size = 10.5, color = "gray25", margin = margin(b = 10)),
    plot.caption = element_text(size = 8.5, color = "gray40", hjust = 0, margin = margin(t = 10)),
    axis.title.x = element_text(face = "bold", size = 11, margin = margin(t = 8)),
    axis.text.y = element_text(face = "bold", size = 10.5, color = "gray15"),
    axis.text.x = element_text(size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.4),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    legend.text = element_text(size = 9.5),
    plot.margin = margin(t = 12, r = 16, b = 12, l = 12)
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig14_race_genre_odds.png", p, width = 9.5, height = 8, dpi = 300, bg = "white")
cat("Saved Plots/fig14_race_genre_odds.png and cache/race_odds_by_genre.csv\n")
print(as.data.frame(cred_summary |> filter(State == "Overclaiming (Like Only vs. Neither)")))
