#' @title Figure 7 preview: education-by-genre overclaiming odds against prestige
#' @description Companion to Figure 6, using Model 6 (education slopes in the
#'   genre random effects) instead of Model 4 (arts slopes). For each genre the
#'   plot pairs the genre-specific education slope for overclaiming, expressed
#'   as an odds ratio across the full six-category range of education, with the
#'   genre's educational prestige (College Preference Ratio). Styled to match
#'   Figure 6: posterior medians with 95% credible intervals on the odds ratio.
#'
#'   Read from cache, not from the fit: cache/m6_educ_genre_slopes.csv holds the
#'   posterior medians and 95% bounds produced by
#'   Scripts/main/check_education_prestige_correlation.R, so this script runs in seconds and
#'   needs no fit in memory.
#'
#'   Note on interpretation: educational prestige is itself built from an
#'   education contrast, so the two axes share the education variable. Read the
#'   correlation as describing how tightly education slopes follow the prestige
#'   ordering, not as an independent causal test.
#'
#'   Output: Plots/fig7_educ_prestige_vs_odds.png

library(ggplot2)
library(ggrepel)
library(dplyr)

slopes <- read.csv("cache/m6_educ_genre_slopes.csv", stringsAsFactors = FALSE)
stopifnot(nrow(slopes) == 20)

# educ2 enters as a linear term over six ordered categories, so the full-range
# contrast is five steps (less than high school to graduate degree).
n_steps <- 5

d <- slopes %>%
  mutate(
    odds_ratio = exp(educ_slope_med * n_steps),
    or_lo = exp(educ_slope_lo * n_steps),
    or_hi = exp(educ_slope_hi * n_steps),
    pref_cat = case_when(
      ratio_col < 1.0 ~ "Less Preferred (< 1.0)",
      ratio_col >= 1.0 & ratio_col <= 1.25 ~ "Slightly Preferred (1.0 - 1.25)",
      ratio_col > 1.25 ~ "Preferred (> 1.25)"
    ),
    pref_cat = factor(
      pref_cat,
      levels = c("Preferred (> 1.25)", "Slightly Preferred (1.0 - 1.25)", "Less Preferred (< 1.0)")
    )
  )

pref_colors <- c(
  "Preferred (> 1.25)"              = "#1b9e77",
  "Slightly Preferred (1.0 - 1.25)" = "#d95f02",
  "Less Preferred (< 1.0)"          = "gray50"
)

# Annotate with the draw-level posterior correlations, so the figure reports the
# same quantity as the text rather than a correlation of point medians.
cor_tab <- read.csv("cache/m6_educ_prestige_correlations.csv", stringsAsFactors = FALSE)
r_prestige_or <- cor_tab$Median[cor_tab$Statistic == "Pearson r (education slope vs prestige)"]
rho_prestige_or <- cor_tab$Median[cor_tab$Statistic == "Spearman rho (education slope vs prestige)"]

p <- ggplot(d, aes(x = ratio_col, y = odds_ratio)) +
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
    "label",
    x = min(d$ratio_col), y = max(d$or_hi) * 1.02,
    label = sprintf("Posterior median\nPearson r = %.2f\nSpearman \u03c1 = %.2f", r_prestige_or, rho_prestige_or),
    hjust = 0, vjust = 1, size = 4, fontface = "bold",
    fill = "white", color = "gray20", label.padding = unit(0.5, "lines")
  ) +
  scale_x_continuous(breaks = seq(0.6, 2.2, by = 0.2)) +
  scale_y_continuous(expand = expansion(mult = c(0.06, 0.14))) +
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
    plot.margin = margin(t = 5.5, r = 11, b = 18, l = 5.5)
  ) +
  labs(
    title = "Class Legitimation and the Education Gradient in Overclaiming",
    subtitle = "Educational Class Prestige vs. Genre-Specific Education Odds of Overclaiming",
    x = "Educational Preference Ratio (College Grad % Liking / High School or Less % Liking)",
    y = "Education Odds Ratio for Overclaiming\n(Graduate Degree vs. Less Than High School)",
    caption = paste(
      "Genre education slopes from Model 6 (education slopes in the genre random effects).",
      "Points are posterior medians; vertical bars are 95% credible intervals.",
      "Educational prestige is itself built from an education contrast, so the two axes are not independent.",
      sep = "\n"
    )
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig7_educ_prestige_vs_odds.png", p, width = 9.5, height = 7, dpi = 300, bg = "white")
cat("Saved Plots/fig7_educ_prestige_vs_odds.png\n")
print(d[, c("genre_name", "ratio_col", "odds_ratio", "or_lo", "or_hi", "pref_cat")])
