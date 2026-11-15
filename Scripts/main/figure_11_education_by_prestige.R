#' @title Figure 11: education odds and genre prestige, three engagement states
#' @description Visualizes the direction of the Model 9 education-by-prestige
#'   interaction. For each of the three non-reference states the figure plots the
#'   education odds ratio for the full six-category range (less than high school
#'   to graduate degree) as a function of the genre's College Preference Ratio.
#'   The curve is exp((b_educ + b_int * (p - mean prestige)) * 5), traced from the
#'   joint posterior of the two coefficients, so the band carries their
#'   correlation rather than combining separate intervals.
#'
#'   Draws come from cache/m9_educ_prestige_draws.csv, written by
#'   Scripts/main/post_m9_prestige_draws.R, and the free genre education slopes in
#'   each panel come from cache/m6_educ_slope_by_state.csv, written by
#'   Scripts/main/post_m6_educ_slopes_by_state.R. Points are the twenty genre
#'   slopes estimated with the genre random effects free; the line is the
#'   interaction's version of the same quantity. No fit is loaded here.
#'
#'   Output: Plots/fig11_education_by_prestige.png

library(ggplot2)
library(ggrepel)
library(dplyr)

draws <- read.csv("cache/m9_educ_prestige_draws.csv", stringsAsFactors = FALSE)
stopifnot(nrow(draws) > 0, all(c("draw", "State", "b_educ", "b_int") %in% names(draws)))

prest <- readRDS("rds/ame_genre_constrained.rds")
mean_p <- mean(prest$ratio_col)
grid_p <- seq(min(prest$ratio_col), max(prest$ratio_col), length.out = 120)

# educ2 is a linear term over six ordered categories: five steps end to end.
n_steps <- 5

curves <- lapply(split(draws, draws$State), function(d) {
  p <- rep(grid_p, times = nrow(d))
  or <- exp((rep(d$b_educ, each = length(grid_p)) +
               rep(d$b_int, each = length(grid_p)) * (p - mean_p)) * n_steps)
  data.frame(State = d$State[1], prestige = p, odds_ratio = or)
})
curves <- bind_rows(curves)

band <- curves |>
  group_by(State, prestige) |>
  summarise(lo = quantile(odds_ratio, 0.025),
            med = quantile(odds_ratio, 0.5),
            hi = quantile(odds_ratio, 0.975), .groups = "drop")

# Free genre education slopes from Model 6, all three equations, as a check.
slopes <- read.csv("cache/m6_educ_slope_by_state.csv", stringsAsFactors = FALSE)
stopifnot(nrow(slopes) == 60)
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

ggplot(band, aes(x = prestige, y = med)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = "#a6bddb", alpha = 0.25) +
  geom_line(color = "#2b8cbe", linewidth = 1.1) +
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
  scale_y_log10(limits = c(0.12, 45),
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
ggsave("Plots/fig11_education_by_prestige.png", width = 13.5, height = 6, dpi = 300, bg = "white")
cat("Saved Plots/fig11_education_by_prestige.png\n")
print(band |> filter(prestige %in% range(prestige)) |> as.data.frame())
