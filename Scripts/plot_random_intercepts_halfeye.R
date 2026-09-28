#' @title Plot Genre Random Intercepts via Tidybayes Half-Eye Plots
#' @description Extracts posterior draws for genre-specific random intercepts (u0)
#'   across all three active engagement states from Model 1 (Crossed Random
#'   Intercepts -- the baseline, no-slopes specification) and renders half-eye
#'   density distributions colored by 95% Credible Interval status.
#' @details Produces three high-resolution figures:
#'   - Plots/Random_Intercepts_Overclaiming.png
#'   - Plots/Random_Intercepts_Underclaiming.png
#'   - Plots/Random_Intercepts_True_Engagement.png
#'   CORRECTNESS NOTE: previously loaded model_brms_slopes.rds (Model 5); fixed
#'   to Model 1 to match this figure's "random intercepts" framing.

library(brms)
library(tidybayes)
library(ggdist)
library(ggplot2)
library(dplyr)
library(tibble)

cat("Loading Bayesian Model 1 (Crossed Random Intercepts -- baseline specification)...\n")
if (exists("m_intercepts")) {
  model_fit <- m_intercepts
} else if (file.exists("rds/model_brms_intercepts.rds")) {
  model_fit <- readRDS("rds/model_brms_intercepts.rds")
} else {
  stop("Model file rds/model_brms_intercepts.rds not found.")
}

draws_df <- as_draws_df(model_fit)

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

color_map <- c(
  "Credibly Above Average" = "#0072B2",
  "Credibly Below Average" = "#D55E00",
  "Not Credible (Spans 0)"  = "gray60"
)

#' Generate standardized half-eye distribution plot for genre random intercepts.
#'
#' @param draws_df Posterior draws dataframe from brms fit.
#' @param state_var Parameter name prefix for the engagement state (e.g., 'muLikeOnly').
#' @param title Figure title.
#' @param xlab Label for x-axis.
#' @return A ggplot object.
plot_random_intercept_clean <- function(draws_df, state_var, title, xlab = "Genre Random Intercept Deviation (u0)") {
  cols <- grep(paste0("^r_genre_id__", state_var, "\\[\\d+,Intercept\\]$"), names(draws_df), value = TRUE)
  
  tb_list <- lapply(cols, function(col_name) {
    g_id <- gsub(paste0("^r_genre_id__", state_var, "\\[(\\d+),Intercept\\]$"), "\\1", col_name)
    tibble::tibble(
      genre_id = g_id,
      genre_name = genre_names[g_id],
      u0 = as.numeric(draws_df[[col_name]])
    )
  })
  
  tb <- bind_rows(tb_list)
  
  cred_summary <- tb %>%
    group_by(genre_name) %>%
    summarize(
      median = median(u0),
      q2.5 = quantile(u0, 0.025),
      q97.5 = quantile(u0, 0.975),
      cred_status = case_when(
        q2.5 > 0 ~ "Credibly Above Average",
        q97.5 < 0 ~ "Credibly Below Average",
        TRUE ~ "Not Credible (Spans 0)"
      ),
      .groups = "drop"
    )
  
  genre_order <- cred_summary %>% arrange(median) %>% pull(genre_name)
  
  tb <- tb %>%
    left_join(cred_summary %>% select(genre_name, cred_status), by = "genre_name") %>%
    mutate(
      genre_name = factor(genre_name, levels = genre_order),
      cred_status = factor(cred_status, levels = c("Credibly Above Average", "Credibly Below Average", "Not Credible (Spans 0)"))
    )
  
  p <- ggplot(tb, aes(x = u0, y = genre_name, fill = cred_status, color = cred_status)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray40", linewidth = 0.75) +
    stat_halfeye(
      point_interval = median_qi,
      .width = 0.95,
      point_size = 3.5,
      interval_size = 1.2,
      slab_alpha = 0.35,
      scale = 0.65
    ) +
    scale_fill_manual(values = color_map, name = "Baseline Status (95% CrI)") +
    scale_color_manual(values = color_map, name = "Baseline Status (95% CrI)") +
    theme_minimal(base_size = 13) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      legend.position = "bottom",
      plot.title = element_text(face = "bold", size = 13.5),
      plot.subtitle = element_text(color = "gray30", size = 10.5, margin = margin(b = 8)),
      axis.title.y = element_blank()
    ) +
    labs(
      title = title,
      subtitle = "Posterior Random Intercept Deviations (u0) from Bayesian Crossed Random Intercepts Model",
      x = xlab
    )
  
  return(p)
}

dir.create("Plots", showWarnings = FALSE)

cat("Generating Random Intercept plots...\n")
p_int_overclaim <- plot_random_intercept_clean(draws_df, "muLikeOnly", "Baseline Genre Propensity for Overclaiming (Like Only)")
p_int_underclaim <- plot_random_intercept_clean(draws_df, "muListenOnly", "Baseline Genre Propensity for Underclaiming (Listen Only)")
p_int_true <- plot_random_intercept_clean(draws_df, "muBoth", "Baseline Genre Propensity for True Engagement (Both)")

ggsave("Plots/Random_Intercepts_Overclaiming.png", p_int_overclaim, width = 9, height = 7, dpi = 300)
ggsave("Plots/Random_Intercepts_Underclaiming.png", p_int_underclaim, width = 9, height = 7, dpi = 300)
ggsave("Plots/Random_Intercepts_True_Engagement.png", p_int_true, width = 9, height = 7, dpi = 300)

cat("Done! Random intercept plots successfully exported to Plots/.\n")
