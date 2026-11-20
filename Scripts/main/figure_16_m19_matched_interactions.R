#' @title Figure 16: the matched interactions of Model 19 on the Model 20 scale
#' @description Companion to Plots/fig15_full_cross_interactions.png, drawn in
#'   the same idiom so the two can be read side by side: same three state
#'   panels, same x-axis (interaction in log-odds per standard deviation of its
#'   own moderator) and same axis limits.
#'
#'   Model 19 carries two interactions, not four: arts x popularity and
#'   education x College Preference Ratio. The unmatched cells are simply absent
#'   from that fit rather than estimated as zero, so this panel has two rows
#'   where Figure 15 has four. Reading the two together shows what fixing the
#'   pairing costs: the arts-by-popularity term is larger in the matched fit
#'   than in the full cross, where prestige takes part of it.
#'
#'   Points and intervals come straight from the joint posterior in
#'   cache/m19_moderator_draws.csv (post_m19_moderator_draws.R, 10,000 draws per
#'   state), so no fit is loaded and the figure rebuilds in seconds.
#'
#'   Output: Plots/fig16_m19_matched_interactions.png

library(dplyr)
library(ggplot2)

cat("Reading Model 19 moderator draws...\n")
dr <- read.csv("cache/m19_moderator_draws.csv", stringsAsFactors = FALSE)
stopifnot(nrow(dr) == 30000, length(unique(dr$State)) == 3)

# Moderator spread over the genre population, the same values the fits used
pop <- read.csv("cache/m1_genre_popularity.csv", stringsAsFactors = FALSE)$pop_med
prest <- readRDS("rds/ame_genre_constrained.rds")$ratio_col
stopifnot(length(pop) == 20, length(prest) == 20)
sd_pop <- sd(pop)
sd_prest <- sd(prest)

state_levels <- c("Overclaiming", "Underclaiming", "Consistent Engagement")
row_levels <- c("Education \u00d7 prestige", "Arts \u00d7 popularity")

d <- bind_rows(
  lapply(state_levels, function(st) {
    x <- dr[dr$State == st, ]
    bind_rows(
      data.frame(State = st, Row = row_levels[2],
                 est = x$b_arts_pop_int * sd_pop),
      data.frame(State = st, Row = row_levels[1],
                 est = x$b_educ_ratio_int * sd_prest)
    )
  })
) |>
  group_by(State, Row) |>
  summarise(
    med = median(est),
    lo = quantile(est, 0.025),
    hi = quantile(est, 0.975),
    excludes_zero = quantile(est, 0.025) > 0 | quantile(est, 0.975) < 0,
    .groups = "drop"
  ) |>
  mutate(
    State = factor(State, levels = state_levels),
    Row = factor(Row, levels = row_levels)
  )

p <- (
  ggplot(d, aes(x = med, y = Row))
  + geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.3)
  + geom_errorbar(aes(xmin = lo, xmax = hi, colour = excludes_zero),
                  orientation = "y", width = 0, linewidth = 0.45)
  + geom_point(aes(fill = excludes_zero, colour = excludes_zero),
               shape = 21, size = 2.1, stroke = 0.4)
  + facet_wrap(~State, nrow = 1)
  + scale_x_continuous(limits = c(-0.10, 0.33))
  + scale_colour_manual(values = c(`TRUE` = "grey20", `FALSE` = "grey60"), guide = "none")
  + scale_fill_manual(values = c(`TRUE` = "grey20", `FALSE` = "white"), guide = "none")
  + labs(
    x = "Interaction, log-odds per standard deviation of the moderator",
    y = NULL,
    title = "Matched interactions, Model 19 (the reported fit)",
    subtitle = "Filled points have 95% credible intervals that exclude zero; same scale as the Model 20 panel"
  )
  + theme_bw(base_size = 9)
  + theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    strip.background = element_rect(fill = "grey95", colour = NA),
    strip.text = element_text(size = 9),
    plot.title = element_text(size = 10, face = "plain"),
    plot.subtitle = element_text(size = 8, colour = "grey30"),
    axis.text.y = element_text(size = 8),
    axis.title.x = element_text(size = 8),
    plot.margin = margin(6, 10, 6, 6)
  )
)

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig16_m19_matched_interactions.png", p, width = 6.5, height = 2.2, dpi = 300)
cat("Saved Plots/fig16_m19_matched_interactions.png\n")
print(as.data.frame(d), digits = 3)
