# plot_omnivorousness_capacity.R
# Visualizes the divergence between Abstract Liking (Omnivorousness) 
# and Concrete Listening across levels of Cultural Capital
# Outputs to Plots/ChildArts_Omnivorousness_Capacity.png

library(dplyr)
library(tidyr)
library(ggplot2)

cat("Loading dataset...\n")
df <- readRDS("rds/model_brms_slopes.rds")$data

cat("Calculating person-level statistics...\n")
person_stats <- df %>%
  group_by(id) %>%
  summarize(
    num_liked = sum(engagement_state %in% c("LikeOnly", "Both")),
    num_listened = sum(engagement_state %in% c("ListenOnly", "Both")),
    child_arts = as.integer(as.character(haven::as_factor(first(child_arts), levels = "values"))),
    .groups = "drop"
  )

sum_df <- person_stats %>%
  group_by(child_arts) %>%
  summarize(
    `Abstract Liking (Number of Genres Liked)` = mean(num_liked),
    `Concrete Listening (Number of Genres Listened To)` = mean(num_listened),
    n = n(),
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols = c(`Abstract Liking (Number of Genres Liked)`, `Concrete Listening (Number of Genres Listened To)`),
    names_to = "Engagement Type",
    values_to = "mean_genres"
  )

cat("Building divergence plot...\n")
p_diverge <- ggplot(sum_df, aes(x = child_arts, y = mean_genres, color = `Engagement Type`, group = `Engagement Type`)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3.5) +
  geom_hline(yintercept = 10, linetype = "dashed", color = "darkred", linewidth = 0.8) +
  annotate("text", x = 1.2, y = 10.4, label = "Theoretical 10-Artist Maximum Capacity", color = "darkred", fontface = "bold", size = 4, hjust = 0) +
  scale_x_continuous(breaks = 1:7, labels = c("1 (None)", "2", "3", "4\n(Moderate)", "5", "6", "7 (Extensive)")) +
  scale_y_continuous(breaks = seq(0, 12, by = 2), limits = c(0, 12)) +
  scale_color_manual(values = c("Abstract Liking (Number of Genres Liked)" = "#1b9e77", "Concrete Listening (Number of Genres Listened To)" = "#d95f02")) +
  labs(
    title = "Omnivorous Liking vs. Concrete Listening Capacity",
    subtitle = "Average number of genres liked vs. listened to across levels of Childhood Arts Exposure.",
    x = "Childhood Arts Exposure (Cultural Capital)",
    y = "Average Number of Genres"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, margin = margin(b = 5)),
    plot.subtitle = element_text(size = 11, color = "gray25", margin = margin(b = 15)),
    axis.title.x = element_text(face = "bold", size = 11, margin = margin(t = 12)),
    axis.title.y = element_text(face = "bold", size = 11, margin = margin(r = 12)),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 11),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

dir.create("Plots", showWarnings = FALSE)
output_file <- "Plots/ChildArts_Omnivorousness_Capacity.png"
ggsave(output_file, p_diverge, width = 8.5, height = 6.5, dpi = 300, bg = "white")
cat("SUCCESS: Plot saved to", output_file, "\n")
