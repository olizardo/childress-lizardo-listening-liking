#' @title Covariate-Averaged Prevalence of the Four Engagement States
#' @description Reads the posterior prevalences computed from the M1 v2 fit by
#'   check_state_prevalences.R (posterior_epred averaged over all 28,655
#'   person-genre dyads, 2,000 thinned draws) and plots each state's posterior
#'   mean as a horizontal bar with its 95% credible interval. No fit is loaded; rebuilds in seconds.
#'
#'   The intervals are posterior uncertainty only (parameters plus random
#'   effects), not sampling variability for the population the respondents came
#'   from. The caption should say so, along with the fact that the estimates
#'   reproduce the raw shares to within a tenth of a percentage point.
#'
#'   Output: Plots/fig1_state_prevalences.png

library(ggplot2)
library(dplyr)
library(readr)
library(scales)

d <- read_csv("cache/state_prevalences_marginal_m1.csv", show_col_types = FALSE)

# Model factor levels mapped to the paper's plain terms; ordered by prevalence
# Levels are ordered smallest to largest so the plot runs Neither at the top
d <- d |>
  mutate(state = factor(state,
                        levels = c("ListenOnly", "Both", "LikeOnly", "Neither"),
                        labels = c("Underclaiming", "Consistent", "Overclaiming", "Neither")))

p <- d |>
  ggplot(aes(y = state, x = posterior_mean)) +
  geom_col(aes(x = posterior_mean), fill = "#2b8cbe", width = 0.65) +
  geom_errorbar(aes(xmin = ci_low, xmax = ci_high), orientation = "y", width = 0.22,
                colour = "grey20", linewidth = 0.7) +
  scale_x_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 0.55)) +
  labs(x = "Share of person–genre dyads", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.margin = margin(8, 14, 30, 8))

ggsave("Plots/fig1_state_prevalences.png", plot = p, width = 6.5, height = 3.6, dpi = 300)
p
