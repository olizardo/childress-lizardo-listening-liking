#' @title Figure 3b: Posterior distributions of predicted state probabilities by arts exposure
#' @description Companion to figure_3_predicted_probs.R. Reads the draw-level
#'   probabilities written by post_m1_predicted_prob_draws.R (run on Hoffman2)
#'   and shows the 1,000 posterior draws at each arts level as ridgelines,
#'   instead of collapsing them to a median and 95% band. The quantity is
#'   identical to Figure 3: for each arts level every person-genre row is
#'   predicted with that level and draws are averaged over rows, so the curves
#'   are population-averaged probabilities, not those of a single respondent.
#'
#'   Output: Plots/fig3b_posterior_draws.png
#'
#'   One column with a shared x scale, so a level's spread can be compared
#'   across the four states. The cost of the shared scale is that the Listen
#'   Only distributions (1.2% to 3.4%) collapse to a thin spike against the
#'   33-62% range of Neither; the panel is kept for completeness, and the
#'   per-panel scale is what its own Figure 3 point estimate shows.

suppressMessages({
  library(dplyr)
  library(ggplot2)
  library(ggridges)
})

draws_df <- read.csv("cache/childarts_predicted_probs_draws.csv.gz")
stopifnot(nrow(draws_df) == 28000, all(draws_df$child_arts %in% 1:7))

state_labels <- c(
  "Neither" = "Neither",
  "LikeOnly" = "Like Only (Overclaiming)",
  "Both" = "Both (Consistent Engagement)",
  "ListenOnly" = "Listen Only (Underclaiming)"
)
state_colors <- c(
  "Neither" = "gray45",
  "Like Only (Overclaiming)" = "#0072B2",
  "Both (Consistent Engagement)" = "#009E73",
  "Listen Only (Underclaiming)" = "#D55E00"
)

plot_df <- draws_df |>
  mutate(
    state = factor(state, levels = c("Neither", "LikeOnly", "Both", "ListenOnly"),
                   labels = state_labels[c("Neither", "LikeOnly", "Both", "ListenOnly")]),
    arts = factor(child_arts, levels = 1:7)
  )

ggplot(plot_df, aes(x = prob, y = arts, fill = state, color = state)) +
  geom_density_ridges(alpha = 0.35, linewidth = 0.4, scale = 1.5, rel_min_height = 0.005) +
  # one column, shared x scale, so a level's spread can be compared across states
  facet_wrap(~state, scales = "fixed", ncol = 1) +
  scale_y_discrete(
    breaks = 1:7,
    labels = c("1 (None)", "2", "3", "4 (Moderate)", "5", "6", "7 (Extensive)")
  ) +
  scale_x_continuous(labels = scales::percent) +
  scale_fill_manual(values = state_colors, guide = "none") +
  scale_color_manual(values = state_colors, guide = "none") +
  labs(
    title = "Posterior Distributions of Predicted Engagement-State Probabilities",
    subtitle = paste("Model 1 (crossed random intercepts); 1,000 posterior draws per arts level,",
                     "averaged over all person-genre rows", sep = "\n"),
    x = "Predicted probability",
    y = "Childhood arts exposure"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray30"),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig3b_posterior_draws.png", width = 8, height = 11, dpi = 300, bg = "white")
cat("Saved Plots/fig3b_posterior_draws.png\n")
