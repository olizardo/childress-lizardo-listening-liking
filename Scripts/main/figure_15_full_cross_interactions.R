#' @title Figure 15: the full cross of both moderators on both exposures (Model 20)
#' @description Diagnostic panel for the journal-length full-cross fit. Each row
#'   is one interaction from cache/full_cross_interactions.csv, expressed per
#'   standard deviation of its own moderator so popularity and the College
#'   Preference Ratio are on a common scale (raw coefficients are not
#'   comparable, since the two moderators have very different ranges). Points
#'   are posterior medians, whiskers the 95% credible interval; filled points
#'   are the intervals that exclude zero.
#'
#'   The pattern the panel is built to show is in the overclaiming column: arts
#'   loads negatively on popularity and positively on prestige, at about the same
#'   size per SD, so the two moderators are near mirror images rather than either
#'   one carrying the gradient on its own. Education instead loads positively on
#'   both, more strongly on prestige, and in consistent engagement is credible on
#'   both. Underclaiming carries only the education-by-prestige term.
#'
#'   Reads no fit, so it rebuilds in seconds.
#'
#'   Output: Plots/fig15_full_cross_interactions.png

library(dplyr)
library(ggplot2)

cat("Reading Model 20 interaction table...\n")
int <- read.csv("cache/full_cross_interactions.csv", stringsAsFactors = FALSE)
stopifnot(nrow(int) == 12)

# Moderator spread over the genre population, the same values the fit script used
pop <- read.csv("cache/m1_genre_popularity.csv", stringsAsFactors = FALSE)$pop_med
prest <- readRDS("rds/ame_genre_constrained.rds")$ratio_col
stopifnot(length(pop) == 20, length(prest) == 20)
sd_pop <- sd(pop)
sd_prest <- sd(prest)

state_labels <- c(
  "LikeOnly" = "Overclaiming",
  "ListenOnly" = "Underclaiming",
  "Both" = "Consistent engagement"
)
row_labels <- c(
  "arts|popularity" = "Arts \u00d7 popularity",
  "arts|prestige (CPR)" = "Arts \u00d7 prestige",
  "education|popularity" = "Education \u00d7 popularity",
  "education|prestige (CPR)" = "Education \u00d7 prestige"
)

d <- int |>
  mutate(
    State = factor(state_labels[State], levels = state_labels),
    Row = factor(row_labels[paste0(Exposure, "|", Moderator)],
                 levels = rev(unname(row_labels))),
    sd_mod = ifelse(grepl("popularity", Moderator), sd_pop, sd_prest),
    est = interaction * sd_mod,
    lo = int_CrI_2.5 * sd_mod,
    hi = int_CrI_97.5 * sd_mod,
    excludes_zero = lo > 0 | hi < 0
  )

p <- (
  ggplot(d, aes(x = est, y = Row))
  + geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.3)
  + geom_errorbar(aes(xmin = lo, xmax = hi, colour = excludes_zero),
                  orientation = "y", width = 0, linewidth = 0.45)
  + geom_point(aes(fill = excludes_zero, colour = excludes_zero),
               shape = 21, size = 2.1, stroke = 0.4)
  + facet_wrap(~State, nrow = 1)
  + scale_x_continuous(limits = c(-0.10, 0.33))  # shared with Figure 16
  + scale_colour_manual(values = c(`TRUE` = "grey20", `FALSE` = "grey60"), guide = "none")
  + scale_fill_manual(values = c(`TRUE` = "grey20", `FALSE` = "white"), guide = "none")
  + labs(
    x = "Interaction, log-odds per standard deviation of the moderator",
    y = NULL,
    title = "Full cross of both moderators on both exposures (Model 20)",
    subtitle = "Filled points have 95% credible intervals that exclude zero; whiskers span the interval"
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
ggsave("Plots/fig15_full_cross_interactions.png", p, width = 6.5, height = 3.0, dpi = 300)
cat("Saved Plots/fig15_full_cross_interactions.png\n")
