#' @title Figure 6: genre-specific education odds ratios for overclaiming
#' @description Figure 5 counterpart on the education margin, drawn with the same
#'   half-eye posteriors, colours and theme. For each genre the plot shows the
#'   odds ratio of overclaiming (Like Only vs. Neither) between respondents with
#'   a bachelor's degree or higher and respondents with high school or less,
#'   computed from the genre-specific education slope of Model 6.
#'
#'   educ2 enters as one linear term over six ordered categories, so the
#'   college-and-above versus high-school-or-less contrast is the gap between the
#'   mean of categories 5-6 (5.5) and the mean of categories 1-2 (1.5), four
#'   steps, the same contrast the College Preference Ratio uses.
#'
#'   Reads cache/m6_educ_slope_draws.csv, written by
#'   Scripts/main/post_m6_educ_slope_draws.R (10,000 draws per genre), so
#'   this script runs in seconds and needs no fit in memory.
#'
#'   Outputs Plots/fig6_education_genre_odds.png and
#'   cache/odds_education_by_genre.csv.

library(tidybayes)
library(posterior)
library(dplyr)
library(ggplot2)
library(ggdist)

draws <- read.csv("cache/m6_educ_slope_draws.csv", stringsAsFactors = FALSE)
stopifnot(n_distinct(draws$genre_name) == 20, !any(is.na(draws$total_educ)))

# College and above (categories 5-6) vs. high school or less (categories 1-2).
n_steps <- 4

tb_draws <- draws |>
  mutate(odds_ratio = exp(total_educ * n_steps))

cred_summary <- tb_draws |>
  group_by(genre_name) |>
  summarize(
    pd_above_1 = mean(odds_ratio > 1),
    q2.5 = quantile(odds_ratio, 0.025),
    median = median(odds_ratio),
    q97.5 = quantile(odds_ratio, 0.975),
    .groups = "drop"
  ) |>
  mutate(
    cred_status = case_when(
      pd_above_1 >= 0.975 ~ "Credibly Increases Overclaiming",
      pd_above_1 <= 0.025 ~ "Credibly Decreases Overclaiming",
      TRUE ~ "Not Credible"
    )
  )

write.csv(cred_summary |> arrange(median), "cache/odds_education_by_genre.csv", row.names = FALSE)

genre_levels <- cred_summary |> arrange(median) |> pull(genre_name)
tb_draws <- tb_draws |>
  left_join(cred_summary |> select(genre_name, cred_status), by = "genre_name")
# Set factor levels AFTER the join: dplyr joins coerce factor keys back to character
tb_draws <- tb_draws |> mutate(genre_name = factor(genre_name, levels = genre_levels))

cred_colors <- c(
  "Credibly Increases Overclaiming" = "#0072B2",
  "Credibly Decreases Overclaiming" = "#D55E00",
  "Not Credible"                    = "gray60"
)

p_halfeye_odds <- ggplot(tb_draws, aes(x = odds_ratio, y = genre_name, fill = cred_status, color = cred_status)) +
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
  scale_x_continuous(breaks = seq(0, 4, by = 1)) +
  coord_cartesian(xlim = c(0, 4.5), expand = FALSE) +
  labs(
    title = "Genre-Specific Effect of Education on Overclaiming",
    subtitle = "Bayesian Posterior Odds Ratios (Like Only vs. Neither): Bachelor's Degree or Higher vs. High School or Less",
    x = "Multiplicative Shift in Odds of Overclaiming (Odds Ratio)",
    y = NULL,
    caption = paste0(
      "Contrast compares respondents educated to the bachelor's level or above (education categories 5-6,\n",
      "mean 5.5) with respondents educated to high school or less (categories 1-2, mean 1.5), a four-point\n",
      "gap, matching the contrast behind the College Preference Ratio. Bayesian crossed random coefficients\n",
      "model with genre-specific education slopes (Model 6), corrected data (10,000 post-warmup MCMC\n",
      "draws). Points are posterior medians; bars are 95% credible intervals. Color rule: pd >= 0.975 of\n",
      "the odds ratio exceeding 1, matching the plotted two-sided intervals."
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
ggsave("Plots/fig6_education_genre_odds.png", p_halfeye_odds, width = 9.5, height = 8, dpi = 300, bg = "white")
cat("Saved Plots/fig6_education_genre_odds.png and cache/odds_education_by_genre.csv\n")
print(as.data.frame(cred_summary |> arrange(median)))
