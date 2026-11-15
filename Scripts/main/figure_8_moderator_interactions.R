#' @title Figure 8: the matched moderator interactions in one three-panel figure
#' @description Panel 1: the Model 19 (paper Model 4) arts-exposure-by-popularity
#'   interaction in the overclaiming equation. Panel 2: the education-by-College
#'   Preference Ratio interaction in the overclaiming equation. Panel 3: the
#'   education-by-ratio interaction in the consistent-engagement equation. Each
#'   panel traces exp((b + b_int * (x - mean_x)) * steps) from the joint posterior
#'   of the two coefficients, so the band carries their correlation; the arts
#'   panel uses the five-point contrast (levels 6-7 versus 1-2) and the education
#'   panels the four-point contrast (bachelor's or higher versus high school or
#'   less), the same contrasts as Figure 5.
#'
#'   Curves come from cache/m19_moderator_draws.csv, written by
#'   Scripts/main/post_m19_moderator_draws.R. Points deliberately come from
#'   Model 3 (M11), which estimates free genre slopes in the two liking equations
#'   and carries no interactions, so the grey points are free evidence for the
#'   fitted gradients rather than a restatement of them. No fit is loaded here.
#'
#'   Output: Plots/fig8_moderator_interactions.png

suppressMessages({
  library(ggplot2)
  library(ggrepel)
  library(dplyr)
  library(tidyr)
})

draws <- read.csv("cache/m19_moderator_draws.csv", stringsAsFactors = FALSE)
stopifnot(nrow(draws) == 30000,
          all(c("draw", "State", "b_arts", "b_arts_pop_int", "b_educ", "b_educ_ratio_int") %in% names(draws)))

prest <- read.csv("cache/ame_genre_ratios.csv", stringsAsFactors = FALSE)
if (!"ratio_col" %in% names(prest)) stop("ratio_col missing from ame_genre_ratios.csv")
mean_prest <- mean(prest$ratio_col)
grid_prest <- seq(min(prest$ratio_col), max(prest$ratio_col), length.out = 120)

pop <- read.csv("cache/m1_genre_popularity.csv", stringsAsFactors = FALSE)
mean_pop <- mean(pop$pop_med)
grid_pop <- seq(min(pop$pop_med), max(pop$pop_med), length.out = 120)

arts_steps <- 5   # levels 6-7 versus 1-2
educ_steps <- 4   # bachelor's or higher versus HS or less

# Panel 1: arts x popularity, overclaiming
oc <- draws[draws$State == "Overclaiming", ]
p1 <- expand.grid(x = grid_pop, d = seq_len(nrow(oc))) |>
  mutate(odds_ratio = exp((rep(oc$b_arts, each = length(grid_pop)) +
                             rep(oc$b_arts_pop_int, each = length(grid_pop)) *
                             (x - mean_pop)) * arts_steps),
         Panel = "Arts x Popularity,\nOverclaiming")
# Panel 2: education x CPR, overclaiming
p2 <- expand.grid(x = grid_prest, d = seq_len(nrow(oc))) |>
  mutate(odds_ratio = exp((rep(oc$b_educ, each = length(grid_prest)) +
                             rep(oc$b_educ_ratio_int, each = length(grid_prest)) *
                             (x - mean_prest)) * educ_steps),
         Panel = "Education x CPR,\nOverclaiming")
# Panel 3: education x CPR, consistent engagement
ce <- draws[draws$State == "Consistent Engagement", ]
p3 <- expand.grid(x = grid_prest, d = seq_len(nrow(ce))) |>
  mutate(odds_ratio = exp((rep(ce$b_educ, each = length(grid_prest)) +
                             rep(ce$b_educ_ratio_int, each = length(grid_prest)) *
                             (x - mean_prest)) * educ_steps),
         Panel = "Education x CPR,\nConsistent Engagement")

curves <- bind_rows(p1, p2, p3)
band <- curves |>
  group_by(Panel, x) |>
  summarise(lo = quantile(odds_ratio, 0.025),
            med = quantile(odds_ratio, 0.5),
            hi = quantile(odds_ratio, 0.975), .groups = "drop")
panel_levels <- c("Arts x Popularity,\nOverclaiming",
                  "Education x CPR,\nOverclaiming",
                  "Education x CPR,\nConsistent Engagement")
band$Panel <- factor(band$Panel, levels = panel_levels)

# Free genre slopes from Model 3 (no interactions anywhere)
slopes_arts <- read.csv("cache/m11_arts_slope_by_state.csv", stringsAsFactors = FALSE) |>
  filter(State == "Overclaiming") |>
  transmute(genre_name, x = NA_real_, ratio_col, slope_med, slope_lo, slope_hi,
            Panel = panel_levels[1])
slopes_educ_oc <- read.csv("cache/m11_educ_slope_by_state.csv", stringsAsFactors = FALSE) |>
  filter(State == "Overclaiming") |>
  transmute(genre_name, x = NA_real_, ratio_col, slope_med, slope_lo, slope_hi,
            Panel = panel_levels[2])
slopes_educ_ce <- read.csv("cache/m11_educ_slope_by_state.csv", stringsAsFactors = FALSE) |>
  filter(State == "Consistent Engagement") |>
  transmute(genre_name, x = NA_real_, ratio_col, slope_med, slope_lo, slope_hi,
            Panel = panel_levels[3])

points_df <- bind_rows(slopes_arts, slopes_educ_oc, slopes_educ_ce) |>
  mutate(x = ifelse(Panel == panel_levels[1],
                    pop$pop_med[match(genre_name, pop$genre_name)],
                    ratio_col),
         odds_ratio = exp(slope_med * ifelse(Panel == panel_levels[1], arts_steps, educ_steps)),
         or_lo = exp(slope_lo * ifelse(Panel == panel_levels[1], arts_steps, educ_steps)),
         or_hi = exp(slope_hi * ifelse(Panel == panel_levels[1], arts_steps, educ_steps)),
         Panel = factor(Panel, levels = panel_levels))
stopifnot(!any(is.na(points_df$x)), nrow(points_df) == 60)

# Per-panel interaction coefficient and two-sided Bayesian p
ann <- bind_rows(
  draws |> filter(State == "Overclaiming") |>
    summarise(Panel = panel_levels[1], coef = mean(b_arts_pop_int),
              p = 2 * min(mean(b_arts_pop_int <= 0), mean(b_arts_pop_int >= 0))),
  draws |> filter(State == "Overclaiming") |>
    summarise(Panel = panel_levels[2], coef = mean(b_educ_ratio_int),
              p = 2 * min(mean(b_educ_ratio_int <= 0), mean(b_educ_ratio_int >= 0))),
  draws |> filter(State == "Consistent Engagement") |>
    summarise(Panel = panel_levels[3], coef = mean(b_educ_ratio_int),
              p = 2 * min(mean(b_educ_ratio_int <= 0), mean(b_educ_ratio_int >= 0)))
) |>
  mutate(Panel = factor(Panel, levels = panel_levels),
         x = c(0.22, 0.80, 0.80), y = c(14, 14, 14),
         label = ifelse(p < 0.001, sprintf("\u03b2 = %.3f\np < 0.001", coef),
                        sprintf("\u03b2 = %.3f\np = %.3f", coef, p)))

p <- ggplot(band, aes(x = x, y = med)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = "#a6bddb", alpha = 0.25) +
  geom_line(color = "#2b8cbe", linewidth = 1.1) +
  geom_label(data = ann, aes(x = x, y = y, label = label),
             hjust = 0, vjust = 1, size = 3.1, fontface = "bold",
             color = "gray15", fill = "white", linewidth = 0.4,
             label.padding = grid::unit(0.3, "lines"),
             lineheight = 0.95, inherit.aes = FALSE) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "gray40", linewidth = 0.5) +
  geom_errorbar(data = points_df, aes(x = x, ymin = or_lo, ymax = or_hi),
                width = 0, linewidth = 0.5, color = "gray45", alpha = 0.35,
                inherit.aes = FALSE) +
  geom_point(data = points_df, aes(x = x, y = odds_ratio),
             size = 2, color = "gray30", alpha = 0.75, inherit.aes = FALSE) +
  geom_text_repel(data = points_df, aes(x = x, y = odds_ratio, label = genre_name),
                  size = 2.4, color = "gray25", segment.color = "gray60",
                  segment.size = 0.3, min.segment.length = 0, max.overlaps = Inf,
                  box.padding = 0.4, point.padding = 0.3, force = 14, max.iter = 20000,
                  seed = 42, inherit.aes = FALSE) +
  facet_wrap(~ Panel, nrow = 1, scales = "free_x") +
  coord_cartesian(clip = "off") +
  scale_y_log10(limits = c(0.2, 20),
                breaks = c(0.25, 0.5, 1, 2, 5, 10),
                labels = scales::label_number(accuracy = 0.01)) +
  labs(
    x = NULL,
    y = "Odds ratio (five-point arts contrast;\nfour-point education contrast)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 11),
    axis.title = element_text(face = "bold", size = 11.5),
    axis.title.y = element_text(size = 10.5),
    plot.margin = margin(t = 6, r = 16, b = 10, l = 18)
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig8_moderator_interactions.png", width = 14.5, height = 5.6, dpi = 300, bg = "white")
cat("Saved Plots/fig8_moderator_interactions.png\n")
print(band |> group_by(Panel) |> filter(x %in% range(x)) |> as.data.frame())
