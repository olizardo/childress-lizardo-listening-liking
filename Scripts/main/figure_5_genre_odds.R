#' @title Figure 5 (corrected): Genre overclaiming odds ratios, colored by directional credibility
#' @description Corrected-data version sourced from model_brms_m4_corrected.rds.
#'   CHANGE vs. legacy: genres are now colored by posterior directional
#'   credibility of the odds ratio exceeding 1, using pd >= 0.975 so the color
#'   rule exactly matches the plotted two-sided 95% intervals (audit fix; user
#'   decision 2026-11-12). Colors: Credibly > 1 (blue), Credibly < 1 (orange),
#'   Not Credible (gray). Educational preference coloring was removed from this
#'   figure; prestige contrasts live in Figure 7.
#'   Outputs Plots/fig5_genre_odds.png and
#'   cache/odds_overclaiming_by_genre.csv.

library(brms)
library(tidybayes)
library(posterior)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggdist)

cat("Loading corrected Model 4 (Constrained Over/True Slopes -- preferred specification)...\n")
model_fit <- readRDS("rds/model_brms_m4_corrected.rds")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

cat("Extracting posterior draws with tidybayes::spread_draws...\n")
tb_draws <- model_fit %>%
  spread_draws(b_muLikeOnly_child_arts, r_genre_id__muLikeOnly[genre_id, term]) %>%
  filter(term == "child_arts") %>%
  mutate(
    genre_id = as.character(genre_id),
    genre_name = genre_names[genre_id],
    total_slope = b_muLikeOnly_child_arts + r_genre_id__muLikeOnly,
    # Contrast: mean of arts levels 6-7 (6.5) vs mean of levels 1-2 (1.5), a 5-point gap.
    odds_ratio = exp(total_slope * 5)
  )

cred_summary <- tb_draws %>%
  group_by(genre_name) %>%
  summarize(
    pd_above_1 = mean(odds_ratio > 1),
    q2.5 = quantile(odds_ratio, 0.025),
    median = median(odds_ratio),
    q97.5 = quantile(odds_ratio, 0.975),
    .groups = "drop"
  ) %>%
  mutate(
    cred_status = case_when(
      pd_above_1 >= 0.975 ~ "Credibly Increases Overclaiming",
      pd_above_1 <= 0.025 ~ "Credibly Decreases Overclaiming",
      TRUE ~ "Not Credible"
    )
  )

dir.create("cache", showWarnings = FALSE)
write.csv(cred_summary %>% arrange(median), "cache/odds_overclaiming_by_genre.csv", row.names = FALSE)
cat("Saved per-genre overclaiming odds ratio summary to cache/odds_overclaiming_by_genre.csv\n")
cat("\nGenres in the old pd 0.95-0.975 window (colored 'Not Credible' under the new rule):\n")
print(cred_summary %>% filter(pd_above_1 >= 0.95, pd_above_1 < 0.975) %>% select(genre_name, pd_above_1))

genre_levels <- cred_summary %>% arrange(median) %>% pull(genre_name)
tb_draws <- tb_draws %>% left_join(cred_summary %>% select(genre_name, cred_status), by = "genre_name")
# Set factor levels AFTER the join: dplyr joins coerce factor keys back to character
tb_draws <- tb_draws %>% mutate(genre_name = factor(genre_name, levels = genre_levels))

cred_colors <- c(
  "Credibly Increases Overclaiming" = "#0072B2",
  "Credibly Decreases Overclaiming" = "#D55E00",
  "Not Credible"                    = "gray60"
)

cat("Building tidybayes half-eye plot...\n")
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
  scale_x_continuous(breaks = seq(0, 15, by = 5)) +
  coord_cartesian(xlim = c(0, 15), expand = FALSE) +
  labs(
    title = "Genre-Specific Effect of Childhood Arts Exposure on Overclaiming",
    subtitle = "Bayesian Posterior Odds Ratios (Like Only vs. Neither): Arts Levels 6-7 vs. Levels 1-2",
    x = "Multiplicative Shift in Odds of Overclaiming (Odds Ratio)",
    y = NULL,
    caption = paste0(
      "Contrast compares respondents at arts levels 6-7 (mean 6.5) with those at levels 1-2 (mean 1.5),\n",
      "a five-point gap. The previous version contrasted level 7 with level 1 (six points), so every\n",
      "value here is lower by construction. Bayesian crossed random coefficients model, corrected data\n",
      "(10,000 post-warmup MCMC draws). Points are posterior medians; bars are 95% credible intervals.\n",
      "Color rule: pd >= 0.975 of the odds ratio exceeding 1, matching the plotted two-sided intervals."
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
output_file <- "Plots/fig5_genre_odds.png"
ggsave(output_file, p_halfeye_odds, width = 9.5, height = 8, dpi = 300, bg = "white")
cat("SUCCESS: Plot saved to", output_file, "\n")
