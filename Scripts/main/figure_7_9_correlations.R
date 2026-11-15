#' @title Figures 7 and 9 (corrected): correlation plots from paper Model 3
#' @description Sourced from cache/m11_genre_summary.csv and
#'   cache/m11_correlations.csv, both written by
#'   Scripts/main/post_m11_genre_effects.R from local Model 11 (paper Model 3,
#'   the restricted arts-and-education random-slope fit). Reads no fit, so it
#'   rebuilds in seconds.
#'   Outputs:
#'   Plots/fig7_intercept_vs_slope.png  (both axes carry 95% credible intervals)
#'   Plots/fig9_prestige_vs_odds.png
#'   cache/correlation_draws_summary.csv
#'   cache/correlation_point_estimates.csv
#'   cache/genre_summary_correlations.csv

library(ggplot2)
library(ggrepel)
library(dplyr)
library(tibble)
library(grid)

cat("Reading Model 11 genre summary (paper Model 3)...\n")
gs <- read.csv("cache/m11_genre_summary.csv", stringsAsFactors = FALSE)
stopifnot(nrow(gs) == 20, !any(is.na(gs$ratio_col)))

pref_levels <- c("Preferred (> 1.25)", "Slightly Preferred (1.0 - 1.25)", "Less Preferred (< 1.0)")

# Figure 9 keeps its six-point contrast (arts level 7 versus level 1), the
# or6_* columns; Figure 5 carries the five-point contrast the text reports.
genre_summary <- gs |>
  transmute(
    genre_name,
    u0_med, u1_med, u0_lo, u0_hi, u1_lo, u1_hi,
    or_med = or6_med, or_lo = or6_lo, or_hi = or6_hi,
    ratio_col, ratio_black,
    pref_cat = factor(pref_cat, levels = pref_levels)
  )

cr <- read.csv("cache/m11_correlations.csv", stringsAsFactors = FALSE)
pick <- function(nm) cr[cr$Statistic == nm, c("Median", "CrI_2.5", "CrI_97.5")]

cor_draws_report <- tibble::tibble(
  Statistic = c("Pearson r (Class Prestige)", "Spearman rho (Class Prestige)",
                "Spearman rho (Racial Preference)"),
  Median = c(pick("arts_prestige_pearson")$Median,
             pick("arts_prestige_spearman")$Median,
             pick("arts_racial_spearman")$Median),
  CrI_2.5 = c(pick("arts_prestige_pearson")$CrI_2.5,
              pick("arts_prestige_spearman")$CrI_2.5,
              pick("arts_racial_spearman")$CrI_2.5),
  CrI_97.5 = c(pick("arts_prestige_pearson")$CrI_97.5,
               pick("arts_prestige_spearman")$CrI_97.5,
               pick("arts_racial_spearman")$CrI_97.5)
)

dir.create("cache", showWarnings = FALSE)
write.csv(cor_draws_report, "cache/correlation_draws_summary.csv", row.names = FALSE)
cat("\n===== POSTERIOR DRAW-WISE CORRELATION SUMMARY (paper Model 3) =====\n")
print(cor_draws_report)

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
    caption = "Extracted from the Bayesian crossed random slopes model (paper Model 3)."
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
      "Odds ratios extracted from the Bayesian crossed random slopes model (paper Model 3);",
      "vertical bars are 95% credible intervals. Class prestige computed from the corrected",
      "model input as the ratio of abstract liking rates among college graduates vs.",
      "respondents with a high school education or less.",
      sep = "\n"
    )
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig7_intercept_vs_slope.png", p_int_slope_corr, width = 9.5, height = 7, dpi = 300, bg = "white")
ggsave("Plots/fig9_prestige_vs_odds.png", p_prestige_corr, width = 9.5, height = 7, dpi = 300, bg = "white")
cat("Successfully generated both corrected correlation plots.\n")
