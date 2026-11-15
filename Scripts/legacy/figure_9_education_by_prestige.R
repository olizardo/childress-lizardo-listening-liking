#' @title Figure 9: education odds and genre prestige, three engagement states
#' @description Visualizes the direction of the Model 14 (paper Model 4)
#'   education-by-prestige interaction. For each of the three non-reference states the figure plots the
#'   education odds ratio for the full six-category range (less than high school
#'   to graduate degree) as a function of the genre's College Preference Ratio.
#'   The curve is exp((b_educ + b_int * (p - mean prestige)) * 5), traced from the
#'   joint posterior of the two coefficients, so the band carries their
#'   correlation rather than combining separate intervals.
#'
#'   Curves come from cache/m14_moderator_draws.csv, written by
#'   Scripts/main/post_m14_moderator_draws.R. The points deliberately come from
#'   fits WITHOUT the prestige interaction, because inside Model 14 the fixed
#'   interaction carries the whole prestige gradient and the genre random slopes
#'   are reduced to small residual departures from the line. Overclaiming and
#'   consistent engagement use cache/m11_educ_slope_by_state.csv (paper Model 3,
#'   the fit behind Figures 5-10); the underclaiming equation has no slopes in
#'   Model 14, so that panel uses the slopes of Model 6, which estimates
#'   education slopes in all three equations. Points are then free evidence for
#'   the interaction, not a restatement of it. No fit is loaded here.
#'
#'   Output: Plots/fig9_education_by_prestige.png

library(ggplot2)
library(ggrepel)
library(dplyr)

draws <- read.csv("cache/m14_moderator_draws.csv", stringsAsFactors = FALSE)
stopifnot(nrow(draws) > 0, all(c("draw", "State", "b_educ", "b_educ_int") %in% names(draws)))

prest <- readRDS("rds/ame_genre_constrained.rds")
mean_p <- mean(prest$ratio_col)
grid_p <- seq(min(prest$ratio_col), max(prest$ratio_col), length.out = 120)

# educ2 is a linear term over six ordered categories: five steps end to end.
n_steps <- 5

curves <- lapply(split(draws, draws$State), function(d) {
  p <- rep(grid_p, times = nrow(d))
  or <- exp((rep(d$b_educ, each = length(grid_p)) +
               rep(d$b_educ_int, each = length(grid_p)) * (p - mean_p)) * n_steps)
  data.frame(State = d$State[1], prestige = p, odds_ratio = or)
})
curves <- bind_rows(curves)

band <- curves |>
  group_by(State, prestige) |>
  summarise(lo = quantile(odds_ratio, 0.025),
            med = quantile(odds_ratio, 0.5),
            hi = quantile(odds_ratio, 0.975), .groups = "drop")

# Free genre education slopes from fits without the prestige interaction: Model 3
# (M11) for the two states it estimates slopes in, and Model 6 for
# underclaiming, which Model 14 leaves with an intercept-only genre effect.
slopes_m11 <- read.csv("cache/m11_educ_slope_by_state.csv", stringsAsFactors = FALSE)
slopes_m6 <- read.csv("cache/m6_educ_slope_by_state.csv", stringsAsFactors = FALSE) |>
  filter(State == "Underclaiming")
slopes <- bind_rows(slopes_m11, slopes_m6)
stopifnot(nrow(slopes) == 60, all(c("Overclaiming", "Underclaiming",
                                    "Consistent Engagement") %in% slopes$State))
points_df <- slopes |>
  transmute(State = State,
            genre_name = genre_name,
            prestige = ratio_col,
            odds_ratio = exp(slope_med * n_steps),
            or_lo = exp(slope_lo * n_steps),
            or_hi = exp(slope_hi * n_steps))

state_levels <- c("Overclaiming", "Underclaiming", "Consistent Engagement")
band$State <- factor(band$State, levels = state_levels)
points_df$State <- factor(points_df$State, levels = state_levels)

# Per-panel interaction coefficient and two-sided Bayesian p.
ann <- draws |>
  group_by(State) |>
  summarise(coef = mean(b_educ_int),
            p = 2 * min(mean(b_educ_int <= 0), mean(b_educ_int >= 0)),
            .groups = "drop") |>
  mutate(State = factor(State, levels = state_levels),
         x = 0.63, y = 30,
         label = ifelse(p < 0.001, sprintf("\u03b2 = %.3f\np < 0.001", coef), sprintf("\u03b2 = %.3f\np = %.3f", coef, p)))

ggplot(band, aes(x = prestige, y = med)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = "#a6bddb", alpha = 0.25) +
  geom_line(color = "#2b8cbe", linewidth = 1.1) +
  geom_label(data = ann, aes(x = x, y = y, label = label),
             hjust = 0, vjust = 1, size = 3.1, fontface = "bold",
             color = "gray15", fill = "white", linewidth = 0.4,
             label.padding = grid::unit(0.3, "lines"),
             lineheight = 0.95, inherit.aes = FALSE) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "gray40", linewidth = 0.5) +
  geom_errorbar(data = points_df, aes(x = prestige, ymin = or_lo, ymax = or_hi),
                width = 0, linewidth = 0.5, color = "gray45", alpha = 0.35,
                inherit.aes = FALSE) +
  geom_point(data = points_df, aes(x = prestige, y = odds_ratio),
             size = 2, color = "gray30", alpha = 0.75, inherit.aes = FALSE) +
  geom_text_repel(data = points_df, aes(x = prestige, y = odds_ratio, label = genre_name),
                  size = 2.4, color = "gray25", segment.color = "gray60",
                  segment.size = 0.3, min.segment.length = 0, max.overlaps = Inf,
                  box.padding = 0.4, point.padding = 0.3, force = 14, max.iter = 20000,
                  seed = 42, inherit.aes = FALSE) +
  facet_wrap(~ State, nrow = 1) +
  coord_cartesian(clip = "off") +
  scale_x_continuous(limits = c(0.58, 2.18), breaks = c(1.0, 1.5, 2.0)) +
  # a common log scale, so the three panels can be compared for slope
  scale_y_log10(limits = c(0.07, 50),
                breaks = c(0.25, 0.5, 1, 2, 5, 10, 20, 40),
                labels = scales::label_number(accuracy = 0.01)) +
  labs(
    x = "College Preference Ratio",
    y = "Education odds ratio\n(less than high school to graduate degree)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 11.5),
    axis.title = element_text(face = "bold", size = 11.5),
    plot.margin = margin(t = 6, r = 16, b = 10, l = 18)
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig9_education_by_prestige.png", width = 13.5, height = 6, dpi = 300, bg = "white")
cat("Saved Plots/fig9_education_by_prestige.png\n")
print(band |> filter(prestige %in% range(prestige)) |> as.data.frame())
