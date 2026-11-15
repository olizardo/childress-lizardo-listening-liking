#' @title Figure 3: Posterior distributions of engagement-state probabilities by childhood arts exposure
#' @description Population-averaged predicted probabilities of the four engagement
#'   states at each childhood arts level, shown as half-eye plots: the full
#'   posterior distribution behind each point rather than a median and a bare
#'   95% band. The quantity is the one the paper reports: for each arts level
#'   every person-genre row is predicted with that level (person and genre
#'   random effects held at their estimates) and the draws are averaged over
#'   rows, so these are population-averaged probabilities, not a single
#'   respondent's. Sources corrected Model 1 (crossed random intercepts,
#'   model_brms_m1_corrected_v2.rds).
#'
#'   Absorbs the ridgeline companion that used to sit in Scripts/legacy/ as
#'   figure_3b_posterior_draws.R.
#'
#'   Inputs: cache/childarts_predicted_probs_draws.csv.gz (1,000 draws per arts
#'   level and state, written by post_m1_predicted_prob_draws.R on Hoffman2;
#'   28,000 rows) and cache/childarts_predicted_probs.csv (the summary table the
#'   manuscript numbers come from).
#'   Output: Plots/fig3_predicted_probs.png
#' @details The draw file is a separate 1,000-draw subsample, so its medians
#'   agree with cache/childarts_predicted_probs.csv to about 0.003 and the tails
#'   differ by that much. Panels carry free x scales: on a shared scale the
#'   Listen Only distributions (about 1.2% to 3.4%) collapse to a spike beside
#'   Neither's 33% to 62%, and the per-level spread is the point of the figure.
#'   Set RECOMPUTE <- TRUE to rebuild the draw file from the fit (needs 24-40 GB
#'   to load the fit).

suppressMessages({
  library(dplyr)
  library(ggplot2)
  library(ggdist)
})

RECOMPUTE <- FALSE

draws_path <- "cache/childarts_predicted_probs_draws.csv.gz"

if (RECOMPUTE || !file.exists(draws_path)) {
  library(brms)

  cat("Loading corrected Model 1 (crossed random intercepts)...\n")
  fit <- readRDS("rds/model_brms_m1_corrected_v2.rds")

  nd_base <- fit$data
  states <- levels(nd_base$engagement_state)  # Neither, ListenOnly, LikeOnly, Both
  stopifnot(states[1] == "Neither")

  ndraws <- 1000
  results <- list()
  for (L in 1:7) {
    cat(sprintf("Arts level %d...\n", L))
    nd <- nd_base
    nd$child_arts <- L
    ep <- posterior_epred(fit, newdata = nd, ndraws = ndraws, summary = FALSE)
    # ep: draws x rows x categories; average over rows within each draw
    state_mean <- apply(ep, c(1, 3), mean)  # draws x categories
    colnames(state_mean) <- states
    results[[L]] <- as.data.frame(state_mean) |>
      mutate(child_arts = L)
    rm(ep, state_mean); gc()
  }

  draws_df <- bind_rows(results) |>
    tidyr::pivot_longer(
      cols = -child_arts,
      names_to = "state",
      values_to = "prob"
    )

  dir.create("cache", showWarnings = FALSE)
  write.csv(draws_df, draws_path, row.names = FALSE)

  # summary table the manuscript numbers come from
  draws_df |>
    group_by(child_arts, state) |>
    summarise(median = median(prob),
              lo = quantile(prob, 0.025),
              hi = quantile(prob, 0.975),
              .groups = "drop") |>
    write.csv("cache/childarts_predicted_probs.csv", row.names = FALSE)
} else {
  cat("Reading cached draws", draws_path, "\n")
  draws_df <- read.csv(draws_path)
}

stopifnot(nrow(draws_df) == 28000, all(draws_df$child_arts %in% 1:7))

state_levels <- c("Neither", "LikeOnly", "Both", "ListenOnly")
state_labels <- c(
  "Neither" = "Neither (No Liking, No Listening)",
  "LikeOnly" = "Like Only (Overclaiming)",
  "Both" = "Both (Consistent Engagement)",
  "ListenOnly" = "Listen Only (Underclaiming)"
)
state_colors <- c(
  "Neither (No Liking, No Listening)" = "gray55",
  "Like Only (Overclaiming)" = "#0072B2",
  "Both (Consistent Engagement)" = "#009E73",
  "Listen Only (Underclaiming)" = "#D55E00"
)

plot_df <- draws_df |>
  mutate(
    state = factor(state, levels = state_levels, labels = unname(state_labels[state_levels])),
    arts = factor(child_arts, levels = 1:7)
  )

p_pred <- ggplot(plot_df, aes(x = prob, y = arts, fill = state, color = state)) +
  stat_halfeye(
    .width = c(0.5, 0.95),
    point_interval = median_qi,
    slab_alpha = 0.45, slab_colour = NA, alpha = 0.9, point_size = 2.2
  ) +
  # free x scales: Listen Only would collapse to a spike on a shared scale
  facet_wrap(~state, scales = "free_x", ncol = 2) +
  scale_y_discrete(
    limits = rev(levels(plot_df$arts)),
    labels = c("1 (None)", "2", "3", "4 (Moderate)", "5", "6", "7 (Extensive)")
  ) +
  scale_x_continuous(labels = scales::percent) +
  scale_fill_manual(values = state_colors, guide = "none") +
  scale_color_manual(values = state_colors, guide = "none") +
  labs(
    title = "Predicted Engagement-State Probabilities by Childhood Arts Exposure",
    subtitle = paste("Model 1 (crossed random intercepts); half-eyes show 1,000 posterior draws per arts level,",
                     "averaged over all person-genre rows. Point = median, thick bar = 50%, thin = 95% interval.",
                     sep = "\n"),
    x = "Predicted probability",
    y = "Childhood arts exposure"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 9.5, color = "gray30"),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig3_predicted_probs.png", p_pred,
       width = 10, height = 6.5, dpi = 300, bg = "white")
cat("Saved Plots/fig3_predicted_probs.png\n")
