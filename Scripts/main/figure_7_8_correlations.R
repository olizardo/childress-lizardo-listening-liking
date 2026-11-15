#' @title Figures 7 and 8 (corrected): correlation plots from corrected Model 4
#' @description Corrected-data version of plot_correlations.R, sourced from
#'   model_brms_m4_corrected.rds and rds/ame_genre_constrained.rds
#'   (built by Scripts/main/prep_genre_preference_ratios.R from the corrected model
#'   input). Updates the legacy caption's draw count to 10,000 post-warmup.
#'   Outputs:
#'   Plots/fig7_intercept_vs_slope.png  (both axes carry 95% credible intervals)
#'   Plots/fig8_prestige_vs_odds.png
#'   cache/correlation_draws_summary.csv
#'   cache/correlation_point_estimates.csv
#'   cache/genre_summary_correlations.csv

library(brms)
library(tidybayes)
library(ggplot2)
library(ggrepel)
library(dplyr)
library(tibble)
library(tidyr)

cat("Loading corrected Model 4 (Constrained Over/True Slopes -- preferred specification)...\n")
model_fit <- readRDS("rds/model_brms_m4_corrected.rds")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

ame_df <- readRDS("rds/ame_genre_constrained.rds")

tb_draws <- model_fit %>%
  spread_draws(
    b_muLikeOnly_Intercept,
    b_muLikeOnly_child_arts,
    r_genre_id__muLikeOnly[genre_id, term]
  )

tb_wide_effects <- tb_draws %>%
  mutate(genre_id = as.character(genre_id)) %>%
  pivot_wider(names_from = term, values_from = r_genre_id__muLikeOnly) %>%
  rename(u0 = Intercept, u1 = child_arts) %>%
  mutate(
    genre_name = genre_names[genre_id],
    total_slope = b_muLikeOnly_child_arts + u1,
    odds_ratio = exp(total_slope * 6)
  )

draw_level <- tb_wide_effects %>%
  left_join(ame_df %>% select(genre_name, ratio_col, ratio_black), by = "genre_name")

cor_draws_summary <- draw_level %>%
  group_by(.draw) %>%
  summarise(
    pearson_prestige = cor(odds_ratio, ratio_col, method = "pearson"),
    spearman_prestige = cor(odds_ratio, ratio_col, method = "spearman"),
    spearman_racial = cor(odds_ratio, ratio_black, method = "spearman"),
    .groups = "drop"
  )

cor_draws_report <- tibble::tibble(
  Statistic = c("Pearson r (Class Prestige)", "Spearman rho (Class Prestige)", "Spearman rho (Racial Preference)"),
  Median = c(
    median(cor_draws_summary$pearson_prestige),
    median(cor_draws_summary$spearman_prestige),
    median(cor_draws_summary$spearman_racial)
  ),
  CrI_2.5 = c(
    quantile(cor_draws_summary$pearson_prestige, 0.025),
    quantile(cor_draws_summary$spearman_prestige, 0.025),
    quantile(cor_draws_summary$spearman_racial, 0.025)
  ),
  CrI_97.5 = c(
    quantile(cor_draws_summary$pearson_prestige, 0.975),
    quantile(cor_draws_summary$spearman_prestige, 0.975),
    quantile(cor_draws_summary$spearman_racial, 0.975)
  )
) %>%
  mutate(across(c(Median, CrI_2.5, CrI_97.5), ~round(., 3)))

dir.create("cache", showWarnings = FALSE)
write.csv(cor_draws_report, "cache/correlation_draws_summary.csv", row.names = FALSE)
cat("\n===== POSTERIOR DRAW-WISE CORRELATION SUMMARY (corrected Model 4) =====\n")
print(cor_draws_report)

genre_summary <- tb_wide_effects %>%
  group_by(genre_name) %>%
  summarise(
    u0_med = median(u0),
    u1_med = median(u1),
    u0_lo = as.numeric(quantile(u0, 0.025)),
    u0_hi = as.numeric(quantile(u0, 0.975)),
    u1_lo = as.numeric(quantile(u1, 0.025)),
    u1_hi = as.numeric(quantile(u1, 0.975)),
    slope_med = median(total_slope),
    or_med = median(odds_ratio),
    or_lo = as.numeric(quantile(odds_ratio, 0.025)),
    or_hi = as.numeric(quantile(odds_ratio, 0.975)),
    .groups = "drop"
  ) %>%
  left_join(ame_df %>% select(genre_name, ratio_col, ratio_black), by = "genre_name") %>%
  mutate(
    pref_cat = case_when(
      ratio_col < 1.0 ~ "Less Preferred (< 1.0)",
      ratio_col >= 1.0 & ratio_col <= 1.25 ~ "Slightly Preferred (1.0 - 1.25)",
      ratio_col > 1.25 ~ "Preferred (> 1.25)"
    ),
    pref_cat = factor(pref_cat, levels = c("Preferred (> 1.25)", "Slightly Preferred (1.0 - 1.25)", "Less Preferred (< 1.0)"))
  )

pref_colors <- c(
  "Preferred (> 1.25)"              = "#1b9e77",
  "Slightly Preferred (1.0 - 1.25)" = "#d95f02",
  "Less Preferred (< 1.0)"          = "gray50"
)

r_u0_u1 <- cor(genre_summary$u0_med, genre_summary$u1_med, method = "pearson")
rho_u0_u1 <- cor(genre_summary$u0_med, genre_summary$u1_med, method = "spearman")
r_prestige_or <- cor(genre_summary$ratio_col, genre_summary$or_med, method = "pearson")
rho_prestige_or <- cor(genre_summary$ratio_col, genre_summary$or_med, method = "spearman")

write.csv(genre_summary, "cache/genre_summary_correlations.csv", row.names = FALSE)
write.csv(
  data.frame(
    Statistic = c("Pearson r (u0 vs u1)", "Spearman rho (u0 vs u1)", "Pearson r (Prestige vs OR, medians)", "Spearman rho (Prestige vs OR, medians)"),
    Value = round(c(r_u0_u1, rho_u0_u1, r_prestige_or, rho_prestige_or), 3)
  ),
  "cache/correlation_point_estimates.csv", row.names = FALSE
)

p_int_slope_corr <- ggplot(genre_summary, aes(x = u0_med, y = u1_med)) +
  geom_smooth(method = "lm", color = "#2b8cbe", fill = "#a6bddb", alpha = 0.25, linewidth = 1.1) +
  geom_errorbarh(
    aes(xmin = u0_lo, xmax = u0_hi),
    height = 0, linewidth = 0.6, color = "gray45", alpha = 0.25
  ) +
  geom_errorbar(
    aes(ymin = u1_lo, ymax = u1_hi),
    width = 0, linewidth = 0.6, color = "gray45", alpha = 0.25
  ) +
  geom_point(aes(color = pref_cat), size = 4, alpha = 0.9) +
  geom_text_repel(
    aes(label = genre_name, color = pref_cat),
    size = 3.8, fontface = "bold",
    box.padding = 0.6, point.padding = 0.5,
    force = 16, force_pull = 0.2,
    max.overlaps = Inf, min.segment.length = 0,
    segment.color = "gray55", segment.size = 0.4, segment.alpha = 0.75,
    seed = 123
  ) +
  scale_color_manual(values = pref_colors, name = "Educational Class Preference") +
  annotate(
    "label", x = 1.0, y = 0.45,
    label = sprintf("Pearson r = %.2f\nSpearman \u03c1 = %.2f", r_u0_u1, rho_u0_u1),
    hjust = 0, vjust = 1, size = 4, fontface = "bold",
    fill = "white", color = "gray20", label.padding = unit(0.5, "lines")
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 14.5, hjust = 0.5),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray30", margin = margin(b = 10)),
    plot.caption = element_text(size = 9, color = "gray40", hjust = 0, margin = margin(t = 10)),
    axis.title.x = element_text(face = "bold", size = 12, margin = margin(t = 8)),
    axis.title.y = element_text(face = "bold", size = 12, margin = margin(r = 8)),
    axis.text = element_text(size = 10.5),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    plot.margin = margin(t = 5.5, r = 11, b = 26, l = 5.5)
  ) +
  labs(
    title = "Baseline Popularity vs. Cultural Capital Sensitivity",
    subtitle = "Posterior Genre Random Intercepts (u0) vs. Arts Random Slopes (u1) for Overclaiming",
    x = expression(bold("Baseline Overclaiming Propensity")~(u["0j, LikeOnly"])),
    y = expression(bold("Childhood Arts Random Slope")~(u["1j, LikeOnly"])),
    caption = "Extracted from the corrected Bayesian crossed random slopes model (Model 4)."
  )

p_prestige_corr <- ggplot(genre_summary, aes(x = ratio_col, y = or_med)) +
  geom_smooth(method = "lm", color = "#2b8cbe", fill = "#a6bddb", alpha = 0.25, linewidth = 1.1) +
  geom_errorbar(
    aes(ymin = or_lo, ymax = or_hi),
    width = 0, linewidth = 0.6, color = "gray45", alpha = 0.25
  ) +
  geom_point(aes(color = pref_cat), size = 4, alpha = 0.9) +
  geom_text_repel(
    aes(label = genre_name, color = pref_cat),
    size = 3.8, fontface = "bold",
    box.padding = 0.7, point.padding = 0.5,
    force = 18, force_pull = 0.2,
    max.overlaps = Inf, min.segment.length = 0,
    segment.color = "gray55", segment.size = 0.4, segment.alpha = 0.75,
    seed = 42
  ) +
  scale_color_manual(values = pref_colors, name = "Educational Class Preference") +
  annotate(
    "label", x = 0.85, y = 22,
    label = sprintf("Pearson r = %.2f\nSpearman \u03c1 = %.2f", r_prestige_or, rho_prestige_or),
    hjust = 0, vjust = 1, size = 4, fontface = "bold",
    fill = "white", color = "gray20", label.padding = unit(0.5, "lines")
  ) +
  scale_x_continuous(breaks = seq(0.6, 2.8, by = 0.4)) +
  scale_y_continuous(breaks = seq(0, 24, by = 4)) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 14.5, hjust = 0.5),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray30", margin = margin(b = 10)),
    plot.caption = element_text(size = 9, color = "gray40", hjust = 0, margin = margin(t = 10)),
    axis.title.x = element_text(face = "bold", size = 12, margin = margin(t = 8)),
    axis.title.y = element_text(face = "bold", size = 12, margin = margin(r = 8)),
    axis.text = element_text(size = 10.5),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    # reserve room for the two-line caption, which was clipped before
    plot.margin = margin(t = 5.5, r = 11, b = 44, l = 5.5)
  ) +
  labs(
    title = "Class Legitimation & Bayesian Overclaiming Odds",
    subtitle = "Educational Class Prestige vs. Genre-Specific Odds of Overclaiming",
    x = "Educational Preference Ratio (College Grad % Liking / High School or Less % Liking)",
    y = "Overclaiming Odds Ratio\n(Arts Exposure L7 vs. L1)",
    caption = paste(
      "Odds ratios extracted from the corrected Bayesian crossed random slopes model (Model 4);",
      "vertical bars are 95% credible intervals. Class prestige computed from the corrected",
      "model input as the ratio of abstract liking rates among college graduates vs.",
      "respondents with a high school education or less.",
      sep = "\n"
    )
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig7_intercept_vs_slope.png", p_int_slope_corr, width = 9.5, height = 7, dpi = 300, bg = "white")
ggsave("Plots/fig8_prestige_vs_odds.png", p_prestige_corr, width = 9.5, height = 7, dpi = 300, bg = "white")
cat("Successfully generated both corrected correlation plots.\n")
