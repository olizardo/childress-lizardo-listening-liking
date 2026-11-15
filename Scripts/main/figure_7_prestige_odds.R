#' @title Figure 7: College Preference Ratio against overclaiming odds for arts
#'   and education, two panels
#' @description Merged version of the two single-panel prestige figures (formerly
#'   two separate figures, one per exposure). For each genre the left
#'   panel pairs the childhood arts exposure odds ratio for overclaiming with the
#'   genre's College Preference Ratio, and the right panel does the same for
#'   education. Both panels come from paper Model 3 (arts and education slopes in
#'   the same genre random effects), via cache/m11_genre_summary.csv and
#'   cache/m11_correlations.csv written by post_m11_genre_effects.R, so the
#'   script needs no fit in memory.
#'
#'   The two panels use different exposure contrasts, so the y axes stay free:
#'   arts is the six-step contrast (exposure level 7 versus level 1) and education
#'   is the five-step contrast (less than high school to graduate degree). The
#'   x axis is shared, which is what makes the tighter education correspondence
#'   visible.
#'
#'   Output: Plots/fig7_prestige_odds.png

# The rho glyph needs a UTF-8 locale when the script runs outside the Positron
# console (plain Rscript inherits C, which drops it).
Sys.setlocale("LC_CTYPE", "en_US.UTF-8")

library(ggplot2)
library(ggrepel)
library(dplyr)
library(tidyr)

gs <- read.csv("cache/m11_genre_summary.csv", stringsAsFactors = FALSE)
stopifnot(nrow(gs) == 20, !any(is.na(gs$ratio_col)))

cor_tab <- read.csv("cache/m11_correlations.csv", stringsAsFactors = FALSE)
lab_row <- function(pear, spea) {
  one <- function(nm, sym) {
    r <- cor_tab[cor_tab$Statistic == nm, ]
    stopifnot(nrow(r) == 1)
    sprintf("%s = %.2f [%.2f, %.2f]", sym, r$Median, r$CrI_2.5, r$CrI_97.5)
  }
  paste(one(pear, "Pearson r"), one(spea, "Spearman \u03c1"), sep = "\n")
}

# Both panels use a five-step contrast, matching the arts contrast reported in the
# text (levels 6-7 versus 1-2) and the full education range (less than high school
# to graduate degree).
n_steps <- 5
d <- gs |>
  mutate(
    arts_or = exp(arts_slope_med * n_steps),
    arts_lo = exp(arts_slope_lo * n_steps),
    arts_hi = exp(arts_slope_hi * n_steps),
    educ_or = exp(educ_slope_med * n_steps),
    educ_lo = exp(educ_slope_lo * n_steps),
    educ_hi = exp(educ_slope_hi * n_steps)
  ) |>
  select(genre_name, ratio_col, pref_cat, arts_or, arts_lo, arts_hi,
         educ_or, educ_lo, educ_hi)

pref_levels <- c("Preferred (> 1.25)", "Slightly Preferred (1.0 - 1.25)", "Less Preferred (< 1.0)")
pref_colors <- c(
  "Preferred (> 1.25)"              = "#1b9e77",
  "Slightly Preferred (1.0 - 1.25)" = "#d95f02",
  "Less Preferred (< 1.0)"          = "gray50"
)
d <- d |> mutate(pref_cat = factor(pref_cat, levels = pref_levels))

long <- bind_rows(
  d |> transmute(genre_name, ratio_col, pref_cat,
                 or = arts_or, lo = arts_lo, hi = arts_hi,
                 Measure = "Childhood Arts Exposure"),
  d |> transmute(genre_name, ratio_col, pref_cat,
                 or = educ_or, lo = educ_lo, hi = educ_hi,
                 Measure = "Education")
) |>
  mutate(Measure = factor(Measure, levels = c("Childhood Arts Exposure", "Education")))

labels_df <- data.frame(
  Measure = factor(c("Childhood Arts Exposure", "Education"),
                   levels = levels(long$Measure)),
  label = c(
    lab_row("arts_prestige_pearson", "arts_prestige_spearman"),
    lab_row("educ_prestige_pearson", "educ_prestige_spearman")
  ),
  x = min(long$ratio_col),
  y = long |> group_by(Measure) |> summarise(m = max(hi) * 1.05, .groups = "drop") |> pull(m)
)

ggplot(long, aes(x = ratio_col, y = or)) +
  geom_smooth(method = "lm", formula = y ~ x,
              color = "#2b8cbe", fill = "#a6bddb", alpha = 0.25, linewidth = 1.1) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0,
                linewidth = 0.4, alpha = 0.5) +
  geom_point(aes(color = pref_cat), size = 2.8, alpha = 0.9) +
  geom_text_repel(aes(label = genre_name, color = pref_cat), size = 2.4,
                  max.overlaps = Inf, min.segment.length = 0,
                  segment.size = 0.2, show.legend = FALSE, seed = 42) +
  geom_label(data = labels_df, aes(x = x, y = y, label = label),
             inherit.aes = FALSE, hjust = 0, vjust = 1, size = 3.1,
             fontface = "bold", fill = "white", color = "gray20",
             label.padding = unit(0.45, "lines"), linewidth = 0.2) +
  facet_wrap(~ Measure, scales = "free_y", nrow = 1) +
  scale_color_manual(values = pref_colors, name = "College Preference Ratio") +
  scale_x_continuous(breaks = seq(0.6, 2.2, by = 0.2)) +
  # Odds ratios are multiplicative, so a log axis keeps the two panels comparable
  # and stops the genre with the widest interval from setting the whole scale.
  scale_y_log10(breaks = c(0.5, 1, 2, 5, 10, 20), labels = c("0.5", "1", "2", "5", "10", "20")) +
  labs(x = "College Preference Ratio", y = "Genre Odds Ratio for Overclaiming",
       title = "The Genre Hierarchy and the Two Cultural Capital Gradients",
       subtitle = paste0("Twenty genres, log odds ratio scale. Both panels use a five-step contrast: arts ",
                         "levels 6-7 versus 1-2,\neducation from less than high school to graduate degree. ",
                         "Bars are 95% credible intervals.")) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_blank(),
        plot.subtitle = element_text(size = 9, color = "gray30"))

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig7_prestige_odds.png", width = 13, height = 6.8, dpi = 300, bg = "white",
       device = ragg::agg_png)
cat("Saved Plots/fig7_prestige_odds.png\n")
