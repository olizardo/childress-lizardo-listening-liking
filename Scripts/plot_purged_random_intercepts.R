#' @title Plot Purged Genre Random Intercepts (3-Panel Engagement Profiles)
#' @description Extracts posterior draws for genre random intercepts (u0) across all three
#'   active engagement states from the preferred Bayesian crossed random slopes model,
#'   centers them within-genre across states to purge the shared baseline popularity effect,
#'   and renders a composite 3-panel tidybayes half-eye distribution plot.
#' @details Uses a directional credibility threshold where >= 95% of posterior draws
#'   fall on one side of zero (pd >= 0.95).
#'   Generates: Plots/Purged_Genre_Engagement_Profiles.png

library(brms)
library(tidybayes)
library(ggdist)
library(ggplot2)
library(dplyr)
library(tibble)
library(tidyr)

cat("Loading Bayesian Random Slopes Model...\n")
if (exists("m_slopes")) {
  model_fit <- m_slopes
} else if (file.exists("rds/model_brms_slopes.rds")) {
  model_fit <- readRDS("rds/model_brms_slopes.rds")
} else {
  stop("Model file rds/model_brms_slopes.rds not found.")
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
  "Not Credible"           = "gray60"
)

# Extract intercepts for all 3 states
state_prefixes <- c(
  "Like Only (Overclaim)" = "muLikeOnly",
  "Listen Only (Underclaim)" = "muListenOnly",
  "Consistent (Both)" = "muBoth"
)

tb_all_list <- lapply(names(state_prefixes), function(st_name) {
  st_var <- state_prefixes[st_name]
  cols <- grep(paste0("^r_genre_id__", st_var, "\\[\\d+,Intercept\\]$"), names(draws_df), value = TRUE)
  
  lapply(cols, function(col_name) {
    g_id <- gsub(paste0("^r_genre_id__", st_var, "\\[(\\d+),Intercept\\]$"), "\\1", col_name)
    tibble::tibble(
      genre_id = g_id,
      genre_name = genre_names[g_id],
      state = st_name,
      .draw = draws_df$.draw,
      u0 = as.numeric(draws_df[[col_name]])
    )
  }) |> bind_rows()
}) |> bind_rows()

# Reshape wide to compute mean across the 3 states per genre and draw
tb_wide <- tb_all_list |>
  pivot_wider(names_from = state, values_from = u0) |>
  mutate(
    u_mean = (`Consistent (Both)` + `Like Only (Overclaim)` + `Listen Only (Underclaim)`) / 3,
    `Like Only (Overclaim)` = `Like Only (Overclaim)` - u_mean,
    `Listen Only (Underclaim)` = `Listen Only (Underclaim)` - u_mean,
    `Consistent (Both)` = `Consistent (Both)` - u_mean
  ) |>
  pivot_longer(
    cols = c(`Like Only (Overclaim)`, `Listen Only (Underclaim)`, `Consistent (Both)`),
    names_to = "state", values_to = "purged_u0"
  )

# Summary stats per genre and state with 95% directional credibility rule (pd >= 0.95)
cred_summary <- tb_wide |>
  group_by(state, genre_name) |>
  summarise(
    median = median(purged_u0),
    q5 = quantile(purged_u0, 0.05),
    q95 = quantile(purged_u0, 0.95),
    prop_pos = mean(purged_u0 > 0),
    prop_neg = mean(purged_u0 < 0),
    cred_status = case_when(
      prop_pos >= 0.95 ~ "Credibly Above Average",
      prop_neg >= 0.95 ~ "Credibly Below Average",
      TRUE ~ "Not Credible"
    ),
    .groups = "drop"
  )

# Genre ordering by Overclaiming median tilt
genre_order_overclaim <- cred_summary |>
  filter(state == "Like Only (Overclaim)") |>
  arrange(median) |>
  pull(genre_name)

tb_wide <- tb_wide |>
  left_join(cred_summary |> select(state, genre_name, cred_status), by = c("state", "genre_name")) |>
  mutate(
    genre_name = factor(genre_name, levels = genre_order_overclaim),
    state = factor(state, levels = c("Like Only (Overclaim)", "Listen Only (Underclaim)", "Consistent (Both)")),
    cred_status = factor(cred_status, levels = c("Credibly Above Average", "Credibly Below Average", "Not Credible"))
  )

# Render composite 3-panel plot
p_purged_combined <- ggplot(tb_wide, aes(x = purged_u0, y = genre_name, fill = cred_status, color = cred_status)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray40", linewidth = 0.75) +
  stat_halfeye(
    point_interval = median_qi,
    .width = 0.95,
    point_size = 2.5,
    interval_size = 0.9,
    slab_alpha = 0.35,
    scale = 0.65
  ) +
  facet_wrap(~ state, scales = "free_x", ncol = 3) +
  scale_fill_manual(values = color_map, name = "Directional Credibility (≥95% on one side of 0)") +
  scale_color_manual(values = color_map, name = "Directional Credibility (≥95% on one side of 0)") +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray30", margin = margin(b = 10)),
    strip.text = element_text(face = "bold", size = 12),
    axis.text.y = element_text(size = 10, face = "bold"),
    axis.text.x = element_text(size = 9),
    axis.title.x = element_text(size = 11, face = "bold", margin = margin(t = 10)),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "gray90"),
    panel.spacing = unit(1.2, "lines")
  ) +
  labs(
    title = "Relative Genre Complex Taste Profiles (Purged of Baseline Popularity)",
    subtitle = expression(bold("Within-genre centered random intercepts:")~u[paste("0", j, k)] - bar(u)[paste("0", j)]~(Ordered~by~Overclaiming~tilt)),
    x = "Relative Log-Odds Deviation from Genre Mean Engagement",
    y = NULL
  )

dir.create("Plots", showWarnings = FALSE)
ggsave("Plots/Purged_Genre_Engagement_Profiles.png", p_purged_combined, width = 13, height = 8, dpi = 300)

cat("Successfully generated Plots/Purged_Genre_Engagement_Profiles.png with 95% directional credibility rule!\n")
