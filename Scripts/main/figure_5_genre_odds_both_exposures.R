#' @title Figure 5: genre-specific overclaiming odds for arts exposure and
#'   education, two panels
#' @description Merged version of the two half-eye figures (formerly Figure 5 for
#'   arts exposure and Figure 6 for education), built the same way as
#'   figure_2_profiles.R: one ggplot with a per-panel y key so each panel carries
#'   its own ordering, then the key prefix is stripped for display. Each panel is
#'   sorted by its own median odds ratio, which is what makes the reordering
#'   across the two exposures visible.
#'
#'   The contrasts differ in width, arts levels 6-7 versus 1-2 (five steps) and
#'   bachelor's degree or higher versus high school or less (four steps), so both
#'   axes stay free.
#'
#'   Reads cache/m11_arts_slope_draws.csv and cache/m11_educ_slope_draws.csv,
#'   written by Scripts/main/post_m11_genre_effects.R (paper Model 3 = local
#'   Model 11), so no fit is needed in memory. Also refreshes
#'   cache/odds_overclaiming_by_genre.csv and cache/odds_education_by_genre.csv.
#'
#'   Output: Plots/fig5_genre_odds_both.png

Sys.setlocale("LC_CTYPE", "en_US.UTF-8")

library(dplyr)
library(ggplot2)
library(ggdist)

cred_colors <- c(
  "Credibly Increases Overclaiming" = "#0072B2",
  "Credibly Decreases Overclaiming" = "#D55E00",
  "Not Credible"                    = "gray60"
)

arts <- read.csv("cache/m11_arts_slope_draws.csv", stringsAsFactors = FALSE)
educ <- read.csv("cache/m11_educ_slope_draws.csv", stringsAsFactors = FALSE)
stopifnot(n_distinct(arts$genre_name) == 20, !any(is.na(arts$total_arts)),
          n_distinct(educ$genre_name) == 20, !any(is.na(educ$total_educ)))

summarise_cred <- function(d) {
  d |>
    group_by(genre_name) |>
    summarize(
      pd_above_1 = mean(odds_ratio > 1),
      q2.5 = quantile(odds_ratio, 0.025),
      median = median(odds_ratio),
      q97.5 = quantile(odds_ratio, 0.975),
      .groups = "drop"
    ) |>
    mutate(cred_status = case_when(
      pd_above_1 >= 0.975 ~ "Credibly Increases Overclaiming",
      pd_above_1 <= 0.025 ~ "Credibly Decreases Overclaiming",
      TRUE ~ "Not Credible"
    ))
}

measure_levels <- c("Childhood Arts Exposure (levels 6-7 vs. 1-2)",
                    "Education (bachelor's or higher vs. high school or less)")

tb_arts <- arts |>
  mutate(odds_ratio = exp(total_arts * 5),
         Measure = measure_levels[1])
tb_educ <- educ |>
  mutate(odds_ratio = exp(total_educ * 4),
         Measure = measure_levels[2])

cred_arts <- summarise_cred(tb_arts)
cred_educ <- summarise_cred(tb_educ)
write.csv(cred_arts |> arrange(median), "cache/odds_overclaiming_by_genre.csv", row.names = FALSE)
write.csv(cred_educ |> arrange(median), "cache/odds_education_by_genre.csv", row.names = FALSE)

tb <- bind_rows(
  tb_arts |> left_join(cred_arts |> select(genre_name, cred_status), by = "genre_name"),
  tb_educ |> left_join(cred_educ |> select(genre_name, cred_status), by = "genre_name")
) |>
  mutate(Measure = factor(Measure, levels = measure_levels))

# Per-panel ordering, as in figure_2_profiles.R: each panel is sorted by its own
# median, ascending, so the largest odds ratio sits at the top.
panel_order <- tb |>
  group_by(Measure, genre_name) |>
  summarise(median = median(odds_ratio), .groups = "drop") |>
  group_by(Measure) |>
  arrange(median, .by_group = TRUE) |>
  mutate(y_key = paste(Measure, genre_name, sep = " | ")) |>
  ungroup()

tb <- tb |>
  left_join(panel_order |> select(Measure, genre_name, y_key), by = c("Measure", "genre_name")) |>
  mutate(
    y_key = factor(y_key, levels = panel_order$y_key),
    cred_status = factor(cred_status, levels = names(cred_colors))
  )

# Trim each genre's slab to its central 99% so a handful of extreme tail draws do
# not stretch the axis (arts reaches 24 on the untrimmed draws, 10.7 at the 99.5th
# percentile). Intervals, points and medians are computed on the full draws above.
tb <- tb |>
  group_by(Measure, genre_name) |>
  filter(odds_ratio >= quantile(odds_ratio, 0.005), odds_ratio <= quantile(odds_ratio, 0.995)) |>
  ungroup()

p <- ggplot(tb, aes(x = odds_ratio, y = y_key, fill = cred_status, color = cred_status)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray40", linewidth = 0.75) +
  stat_halfeye(
    point_interval = ggdist::median_qi,
    .width = 0.95,
    point_size = 2.5,
    interval_size = 0.9,
    slab_alpha = 0.35,
    scale = 0.9
  ) +
  facet_wrap(~ Measure, scales = "free", nrow = 1) +
  scale_y_discrete(labels = function(x) sub("^.* \\| ", "", x)) +
  scale_fill_manual(values = cred_colors, name = "Directional Credibility") +
  scale_color_manual(values = cred_colors, name = "Directional Credibility") +
  labs(
    title = "Genre-Specific Effects of the Two Cultural Capital Indicators on Overclaiming",
    subtitle = paste0("Posterior odds ratios (Like Only vs. Neither), each panel ordered by its own effect size. ",
                      "The two contrasts differ in width,\nso the odds ratio axes are not on a common scale."),
    x = "Multiplicative Shift in Odds of Overclaiming (Odds Ratio)",
    y = NULL,
    caption = paste0(
      "Points are posterior medians; bars are 95% credible intervals; slabs are posterior densities. ",
      "Color rule: pd >= 0.975 of the odds\nratio exceeding 1, matching the plotted two-sided intervals. ",
      "Genre-specific slopes from the same model (paper Model 3), 10,000\npost-warmup draws. Arts contrast ",
      "is five steps (levels 6-7, mean 6.5, versus levels 1-2, mean 1.5); education contrast is\nfour steps ",
      "(categories 5-6, mean 5.5, versus categories 1-2, mean 1.5)."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13.5, margin = margin(b = 5)),
    plot.subtitle = element_text(size = 10, color = "gray30", margin = margin(b = 10)),
    plot.caption = element_text(size = 8, color = "gray40", hjust = 0, margin = margin(t = 8)),
    strip.text = element_text(face = "bold", size = 10.5),
    axis.text.y = element_text(face = "bold", size = 9.5, color = "gray15"),
    axis.text.x = element_text(size = 9),
    axis.title.x = element_text(face = "bold", size = 10.5, margin = margin(t = 8)),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    legend.text = element_text(size = 9),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.35),
    panel.grid.major.x = element_blank(),
    panel.spacing = unit(1.2, "lines")
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig5_genre_odds_both.png", p, width = 13, height = 8.5, dpi = 300,
       bg = "white", device = ragg::agg_png)
cat("Saved Plots/fig5_genre_odds_both.png\n")
