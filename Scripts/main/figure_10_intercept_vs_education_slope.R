#' @title Figure 10: genre intercepts against genre education slopes
#' @description Education counterpart to Figure 7. For each genre the plot pairs
#'   the random intercept of the overclaiming equation, evaluated at the sample's
#'   mean education, with that genre's total education slope for overclaiming.
#'   Figure 7 asks whether the arts effect is largest where baseline engagement is
#'   lowest (the scarcity reading); this panel asks whether the education gradient
#'   is simply a restatement of baseline popularity.
#'
#'   Reads cache/m6_intercept_educ_genre.csv and
#'   cache/m6_intercept_educ_correlation.csv, both written by
#'   Scripts/main/check_m6_intercept_educ_correlation.R (Model 6). Needs no fit in
#'   memory and rebuilds in seconds.
#'
#'   Output: Plots/fig10_intercept_vs_education_slope.png

library(ggplot2)
library(ggrepel)
library(dplyr)

genres <- read.csv("cache/m6_intercept_educ_genre.csv", stringsAsFactors = FALSE)
cors <- read.csv("cache/m6_intercept_educ_correlation.csv", stringsAsFactors = FALSE)
stopifnot(nrow(genres) == 20)

r_mean <- cors$Median[cors$Statistic == "Intercept at mean education vs. education slope (Pearson)"]
rho_mean <- cors$Median[cors$Statistic == "Intercept at mean education vs. education slope (Spearman)"]
stopifnot(length(r_mean) == 1, length(rho_mean) == 1)

d <- genres |>
  mutate(
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

p <- ggplot(d, aes(x = u0_med, y = educ_slope_med)) +
  geom_smooth(method = "lm", color = "#2b8cbe", fill = "#a6bddb", alpha = 0.25, linewidth = 1.1) +
  geom_errorbarh(
    aes(xmin = u0_lo, xmax = u0_hi),
    height = 0, linewidth = 0.6, color = "gray45", alpha = 0.25
  ) +
  geom_errorbar(
    aes(ymin = educ_slope_lo, ymax = educ_slope_hi),
    width = 0, linewidth = 0.6, color = "gray45", alpha = 0.25
  ) +
  geom_point(aes(color = pref_cat), size = 4, alpha = 0.9) +
  geom_text_repel(
    aes(label = genre_name, color = pref_cat),
    size = 3.8, fontface = "bold",
    box.padding = 0.7, point.padding = 0.5,
    force = 16, force_pull = 0.2,
    max.overlaps = Inf, min.segment.length = 0,
    segment.color = "gray55", segment.size = 0.4, segment.alpha = 0.75,
    seed = 7
  ) +
  scale_color_manual(values = pref_colors, name = "Educational Class Preference") +
  annotate(
    "label", x = min(d$u0_lo), y = max(d$educ_slope_hi),
    label = sprintf("Posterior median\nPearson r = %.2f\nSpearman \u03c1 = %.2f", r_mean, rho_mean),
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
    plot.margin = margin(t = 5.5, r = 11, b = 44, l = 5.5)
  ) +
  labs(
    title = "Baseline Popularity vs. the Education Gradient",
    subtitle = "Posterior Genre Random Intercepts vs. Genre Education Slopes for Overclaiming",
    x = expression(bold("Baseline Overclaiming Propensity")~(u["0j, LikeOnly"]~"at mean education")),
    y = expression(bold("Genre Education Slope for Overclaiming")~(u["2j, LikeOnly"])),
    caption = paste(
      "Intercepts and education slopes extracted from the Bayesian crossed random coefficients model",
      "with education in the genre random effects (Model 6); horizontal and vertical bars are 95%",
      "credible intervals. Intercepts are evaluated at the sample's mean education (educ2 = 3.27),",
      "because the raw intercept sits at educ2 = 0 and education enters the same random-effect block.",
      sep = "\n"
    )
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig10_intercept_vs_education_slope.png", p, width = 9.5, height = 7, dpi = 300, bg = "white")
cat("Saved Plots/fig10_intercept_vs_education_slope.png\n")
print(as.data.frame(d[, c("genre_name", "u0_med", "educ_slope_med", "ratio_col")]))
