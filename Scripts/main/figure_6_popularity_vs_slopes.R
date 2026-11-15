#' @title Figure 6: genre popularity against arts and education slopes
#' @description Correlates model-based genre popularity with the overclaiming
#'   random slopes for childhood arts exposure and education, across the twenty
#'   genres. Popularity comes from the baseline fit (1 - fitted Neither share,
#'   cache/m1_genre_popularity_draws.csv, written by post_m1_genre_popularity.R)
#'   and the slopes from Model 11 (paper Model 3, cache/m11_*_slope_draws.csv).
#'   The two fits are independent, so pairing their draws by index yields a valid
#'   joint posterior sample and the correlation intervals carry both sources of
#'   uncertainty.
#'
#'   Reports Pearson and Spearman, and partial versions controlling for the
#'   College Preference Ratio, since popularity and prestige correlate about
#'   -0.59 across genres.
#'
#'   Outputs: Plots/fig6_popularity_vs_slopes.png,
#'            cache/popularity_slope_correlations.csv,
#'            cache/popularity_slope_points.csv

library(ggplot2)
library(ggrepel)
library(dplyr)
library(tidyr)
library(tibble)

pop <- read.csv("cache/m1_genre_popularity_draws.csv", stringsAsFactors = FALSE) |>
  select(.draw, genre_name, popularity)
arts <- read.csv("cache/m11_arts_slope_draws.csv", stringsAsFactors = FALSE) |>
  select(.draw, genre_name, arts = total_arts)
educ <- read.csv("cache/m11_educ_slope_draws.csv", stringsAsFactors = FALSE) |>
  select(.draw, genre_name, educ = total_educ)
gs <- read.csv("cache/m11_genre_summary.csv", stringsAsFactors = FALSE) |>
  select(genre_name, ratio_col, arts_slope_med, arts_slope_lo, arts_slope_hi,
         educ_slope_med, educ_slope_lo, educ_slope_hi, pref_cat)

stopifnot(nrow(pop) > 0, nrow(arts) > 0, nrow(educ) > 0,
          length(unique(pop$genre_name)) == 20,
          length(unique(arts$genre_name)) == 20,
          setequal(pop$genre_name, arts$genre_name),
          setequal(pop$genre_name, gs$genre_name))

# One popularity draw pairs with one slope draw. The fits are independent, so a
# fixed random subsample of the slope draws is as valid as any other pairing and
# avoids relying on draw-index alignment.
n_pair <- min(length(unique(pop$.draw)), length(unique(arts$.draw)))
set.seed(4157)
keep_arts <- sort(sample(unique(arts$.draw), n_pair))
keep_educ <- sort(sample(unique(educ$.draw), n_pair))
# Pair ids come from the draw ids, never from row order: these files are stored
# genre-major, so a recycled sequence would scramble the pairing.
pop <- pop |>
  filter(.draw %in% sort(unique(.draw))[seq_len(n_pair)]) |>
  mutate(.pair = match(.draw, sort(unique(.draw))[seq_len(n_pair)]))
arts <- arts |> filter(.draw %in% keep_arts) |> mutate(.pair = match(.draw, keep_arts))
educ <- educ |> filter(.draw %in% keep_educ) |> mutate(.pair = match(.draw, keep_educ))

joint <- pop |>
  inner_join(arts, by = c(".pair", "genre_name")) |>
  inner_join(educ, by = c(".pair", "genre_name")) |>
  inner_join(gs |> select(genre_name, ratio_col), by = "genre_name")
stopifnot(nrow(joint) == n_pair * 20, !any(is.na(joint$popularity)))

# Partial correlation of x and y net of z, computed by residualising both on z.
partial_cor <- function(x, y, z) {
  rx <- resid(lm(x ~ z))
  ry <- resid(lm(y ~ z))
  cor(rx, ry, method = "pearson")
}

cor_draws <- joint |>
  group_by(.pair) |>
  summarise(
    arts_pearson = cor(popularity, arts),
    arts_spearman = cor(popularity, arts, method = "spearman"),
    arts_partial_prestige = partial_cor(popularity, arts, ratio_col),
    educ_pearson = cor(popularity, educ),
    educ_spearman = cor(popularity, educ, method = "spearman"),
    educ_partial_prestige = partial_cor(popularity, educ, ratio_col),
    .groups = "drop"
  )

summ <- function(x) {
  data.frame(Median = round(median(x), 3),
             CrI_2.5 = round(quantile(x, 0.025), 3),
             CrI_97.5 = round(quantile(x, 0.975), 3),
             p_bayes = round(2 * min(mean(x <= 0), mean(x >= 0)), 4))
}
cor_report <- bind_rows(lapply(names(cor_draws)[-1], function(nm) {
  cbind(Statistic = nm, summ(cor_draws[[nm]]))
}))
rownames(cor_report) <- NULL
write.csv(cor_report, "cache/popularity_slope_correlations.csv", row.names = FALSE)
cat("\n===== POPULARITY vs GENRE SLOPES (draw level, n = 20 genres) =====\n")
print(as.data.frame(cor_report))

# ---- Points for the figure ------------------------------------------------
pop_pts <- read.csv("cache/m1_genre_popularity.csv", stringsAsFactors = FALSE) |>
  select(genre_name, pop_med, pop_lo, pop_hi)

points <- gs |>
  left_join(pop_pts, by = "genre_name") |>
  select(genre_name, pref_cat, pop_med, pop_lo, pop_hi,
         arts_slope_med, arts_slope_lo, arts_slope_hi,
         educ_slope_med, educ_slope_lo, educ_slope_hi)
stopifnot(nrow(points) == 20, !any(is.na(points$pop_med)))
write.csv(points, "cache/popularity_slope_points.csv", row.names = FALSE)

pref_levels <- c("Preferred (> 1.25)", "Slightly Preferred (1.0 - 1.25)", "Less Preferred (< 1.0)")
pref_colors <- c(
  "Preferred (> 1.25)"              = "#1b9e77",
  "Slightly Preferred (1.0 - 1.25)" = "#d95f02",
  "Less Preferred (< 1.0)"          = "gray50"
)
points <- points |> mutate(pref_cat = factor(pref_cat, levels = pref_levels))

# Two-line boxed label, the same idiom as the other panel figures: Pearson r and Spearman rho, boxed on a
# white fill at the top left of each panel.
lab_for <- function(pear, spea) {
  row <- function(nm, sym) {
    r <- cor_report[cor_report$Statistic == nm, ]
    sprintf("%s = %.2f [%.2f, %.2f]", sym, r$Median, r$CrI_2.5, r$CrI_97.5)
  }
  paste(row(pear, "Pearson r"), row(spea, "Spearman \u03c1"), sep = "\n")
}

# Facets rather than two side-by-side grobs: no extra layout package needed, and
# the legend is shared automatically.
long <- bind_rows(
  points |> transmute(genre_name, pref_cat, pop_med, pop_lo, pop_hi,
                      slope_med = arts_slope_med, slope_lo = arts_slope_lo,
                      slope_hi = arts_slope_hi,
                      Measure = "Childhood Arts Slope for Overclaiming"),
  points |> transmute(genre_name, pref_cat, pop_med, pop_lo, pop_hi,
                      slope_med = educ_slope_med, slope_lo = educ_slope_lo,
                      slope_hi = educ_slope_hi,
                      Measure = "Education Slope for Overclaiming")
) |>
  mutate(Measure = factor(Measure, levels = c("Childhood Arts Slope for Overclaiming",
                                              "Education Slope for Overclaiming")))

labels_df <- data.frame(
  Measure = levels(long$Measure),
  label = c(lab_for("arts_pearson", "arts_spearman"),
            lab_for("educ_pearson", "educ_spearman")),
  # Upper right corner of each panel, where neither density of points reaches.
  x = max(long$pop_hi),
  y = long |> group_by(Measure) |> summarise(m = max(slope_hi), .groups = "drop") |> pull(m)
)

p <- ggplot(long, aes(x = pop_med, y = slope_med)) +
  geom_smooth(method = "lm", formula = y ~ x,
              color = "#2b8cbe", fill = "#a6bddb", alpha = 0.25, linewidth = 1.1) +
  geom_errorbar(aes(ymin = slope_lo, ymax = slope_hi), width = 0,
                linewidth = 0.4, alpha = 0.5) +
  geom_point(aes(color = pref_cat), size = 2.8, alpha = 0.9) +
  geom_text_repel(aes(label = genre_name, color = pref_cat), size = 2.4,
                  max.overlaps = Inf, min.segment.length = 0,
                  segment.size = 0.2, show.legend = FALSE) +
  geom_label(data = labels_df, aes(x = x, y = y, label = label),
             inherit.aes = FALSE, hjust = 1, vjust = 1, size = 3.1,
             fontface = "bold", fill = "white", color = "gray20",
             label.padding = unit(0.45, "lines"), linewidth = 0.2) +
  facet_wrap(~ Measure, scales = "free_y", nrow = 1) +
  scale_color_manual(values = pref_colors, name = "College Preference Ratio") +
  labs(x = "Genre Popularity (1 - fitted Neither probability)", y = "Genre Random Slope (log-odds)",
       title = "Genre Popularity and the Slopes of the Two Capital Indicators",
       subtitle = paste0("Twenty genres. Popularity is estimated from the baseline fit, so it shares no ",
                         "likelihood with the slopes,\nwhich come from Model 3. Bars are 95% credible intervals.")) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_blank(),
        plot.subtitle = element_text(size = 9, color = "gray30"))

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig6_popularity_vs_slopes.png", p, width = 13, height = 6.8, dpi = 300, bg = "white")
cat("\nSaved Plots/fig6_popularity_vs_slopes.png\n")
