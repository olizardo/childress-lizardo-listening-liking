#' @title Figure 2: Predicted probabilities of engagement states by childhood arts exposure
#' @description Corrected-data replacement for the unverifiable legacy
#'   ChildArts_Effects_Bayesian_CrI.png (which had NO generating script; see
#'   2026-11-11 audit). Sources corrected Model 1 (crossed random intercepts,
#'   model_brms_m1_corrected_v2.rds). For each arts level 1-7, every row of the
#'   model data gets its child_arts value replaced (person and genre random
#'   effects held at their estimated values), posterior_epred draws are averaged
#'   within draw across all person-genre rows, giving the population-adjusted
#'   predicted probability of each engagement state. Outputs
#'   Plots/fig2_predicted_probs.png and
#'   cache/childarts_predicted_probs.csv.
#' @details Memory: uses ndraws = 1000 and frees each level's array before the
#'   next, so peak stays around 1 GB per posterior_epred call.

library(brms)
library(dplyr)
library(tidyr)
library(ggplot2)

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
  dimnames(state_mean) <- list(draw = seq_len(ndraws), state = states)
  results[[L]] <- as.data.frame(state_mean) |>
    mutate(child_arts = L)
  rm(ep, state_mean); gc()
}

pred_df <- bind_rows(results) |>
  pivot_longer(
    cols = -child_arts,
    names_to = "state",
    values_to = "prob"
  ) |>
  group_by(child_arts, state) |>
  summarise(
    median = median(prob),
    lo = quantile(prob, 0.025),
    hi = quantile(prob, 0.975),
    .groups = "drop"
  )

state_labels <- c(
  "Neither" = "Neither (No Liking, No Listening)",
  "ListenOnly" = "Listen Only (Underclaiming)",
  "LikeOnly" = "Like Only (Overclaiming)",
  "Both" = "Both (Consistent Engagement)"
)
state_colors <- c(
  "Neither" = "gray55",
  "Like Only (Overclaiming)" = "#0072B2",
  "Both (Consistent Engagement)" = "#009E73",
  "Listen Only (Underclaiming)" = "#D55E00"
)

dir.create("cache", showWarnings = FALSE)
write.csv(pred_df, "cache/childarts_predicted_probs.csv", row.names = FALSE)

pred_df <- pred_df |>
  mutate(state = factor(
    state,
    levels = c("Neither", "LikeOnly", "Both", "ListenOnly"),
    labels = c("Neither", "Like Only (Overclaiming)", "Both (Consistent Engagement)", "Listen Only (Underclaiming)")
  ))

p_pred <- ggplot(pred_df, aes(x = child_arts, y = median, color = state, fill = state)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, color = NA) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3) +
  scale_x_continuous(
    breaks = 1:7,
    labels = c("1 (None)", "2", "3", "4\n(Moderate)", "5", "6", "7 (Extensive)")
  ) +
  scale_y_continuous(
    labels = scales::percent,
    limits = c(0, 0.65),
    breaks = seq(0, 0.6, by = 0.2),
    oob = scales::squish
  ) +
  scale_color_manual(values = state_colors) +
  scale_fill_manual(values = state_colors) +
  labs(
    title = "Predicted Engagement-State Probabilities by Childhood Arts Exposure",
    subtitle = "Corrected data; crossed random-intercepts model (Model 1). Person and genre effects held at posterior estimates; 95% credible bands.",
    x = "Childhood Arts Exposure",
    y = "Predicted Probability"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray30"),
    axis.title.x = element_text(margin = margin(t = 10)),
    strip.text = element_text(face = "bold"),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 10),
    panel.grid.minor = element_blank()
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/fig2_predicted_probs.png", p_pred,
       width = 9.5, height = 6.5, dpi = 300, bg = "white")
cat("Saved Plots/fig2_predicted_probs.png\n")
