# plot_odds_overclaiming_halfeye.R
# Visualizes the marginal effect of moving from lowest to highest arts exposure
# on genre-specific odds of overclaiming using tidybayes + ggdist::stat_halfeye
# Colored by 3-tier Educational Preference Ratio (College Grad / High School Liking Ratio)
# Outputs to Plots/ChildArts_Odds_Overclaiming_HalfEye.png

library(brms)
library(tidybayes)
library(posterior)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggdist)

cat("Loading Bayesian Random Slopes Model...\n")
if (exists("fit_brms_slopes")) {
  model_fit <- fit_brms_slopes
} else if (file.exists("rds/model_brms_slopes.rds")) {
  model_fit <- readRDS("rds/model_brms_slopes.rds")
} else {
  stop("Model file rds/model_brms_slopes.rds not found.")
}

# Genre name mapping
genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

# Load demographic prestige / educational preference ratio
if (file.exists("rds/ame_genre_constrained.rds")) {
  pref_df_3cat <- readRDS("rds/ame_genre_constrained.rds") %>%
    select(genre_name, ratio_col) %>%
    mutate(
      pref_cat = case_when(
        ratio_col < 1.0 ~ "Less Preferred (< 1.0)",
        ratio_col >= 1.0 & ratio_col <= 1.25 ~ "Slightly Preferred (1.0 - 1.25)",
        ratio_col > 1.25 ~ "Preferred (> 1.25)"
      ),
      pref_cat = factor(pref_cat, levels = c("Preferred (> 1.25)", "Slightly Preferred (1.0 - 1.25)", "Less Preferred (< 1.0)"))
    )
} else {
  stop("rds/ame_genre_constrained.rds not found.")
}

cat("Extracting posterior draws with tidybayes::spread_draws...\n")
# Extract fixed effect and genre random slopes for childhood arts on LikeOnly logit
tb_draws <- model_fit %>%
  spread_draws(b_muLikeOnly_child_arts, r_genre_id__muLikeOnly[genre_id, term]) %>%
  filter(term == "child_arts") %>%
  mutate(
    genre_id = as.character(genre_id),
    genre_name = genre_names[genre_id],
    total_slope = b_muLikeOnly_child_arts + r_genre_id__muLikeOnly,
    odds_ratio = exp(total_slope * 6)
  ) %>%
  left_join(pref_df_3cat, by = "genre_name")

cred_summary <- tb_draws %>%
  group_by(genre_name, pref_cat, ratio_col) %>%
  summarize(
    q2.5 = quantile(odds_ratio, 0.025),
    median = median(odds_ratio),
    q97.5 = quantile(odds_ratio, 0.975),
    mean = mean(odds_ratio),
    .groups = "drop"
  )

genre_levels <- cred_summary %>% arrange(median) %>% pull(genre_name)
tb_draws$genre_name <- factor(tb_draws$genre_name, levels = genre_levels)

pref_colors <- c(
  "Preferred (> 1.25)"            = "#1b9e77",
  "Slightly Preferred (1.0 - 1.25)" = "#d95f02",
  "Less Preferred (< 1.0)"        = "gray60"
)

cat("Building tidybayes half-eye plot...\n")
p_halfeye_odds <- ggplot(tb_draws, aes(x = odds_ratio, y = genre_name, fill = pref_cat, color = pref_cat)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray45", linewidth = 0.75) +
  stat_halfeye(
    point_interval = ggdist::median_qi,
    .width = 0.95,
    point_size = 3.5,
    interval_size = 1.2,
    slab_alpha = 0.35,
    scale = 0.7
  ) +
  scale_fill_manual(values = pref_colors, name = "Educational Preference\n(College / HS Liking Ratio)") +
  scale_color_manual(values = pref_colors, name = "Educational Preference\n(College / HS Liking Ratio)") +
  scale_x_continuous(
    breaks = seq(0, 30, by = 5)
  ) +
  coord_cartesian(xlim = c(0, 30), expand = FALSE) +
  labs(
    title = "Marginal Effect of Childhood Arts Exposure on Genre Overclaiming",
    subtitle = "Bayesian Posterior Odds Ratios (Like Only vs. Neither) for Level 7 vs. Level 1 Arts Exposure",
    x = "Multiplicative Shift in Odds of Overclaiming (Odds Ratio)",
    y = NULL,
    caption = "Bayesian crossed random coefficients model (4,000 post-warmup MCMC draws).\nPoints represent posterior medians; horizontal error bars indicate 95% credible intervals.\nGenres colored by Educational Preference Ratio (College Grad % Liking / High School % Liking)."
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
output_file <- "Plots/ChildArts_Odds_Overclaiming_HalfEye.png"
ggsave(output_file, p_halfeye_odds, width = 9.5, height = 8, dpi = 300, bg = "white")
cat("SUCCESS: Plot saved to", output_file, "\n")
