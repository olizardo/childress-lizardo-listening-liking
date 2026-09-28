#' @title Posterior Predictive Check: Observed vs. Predicted Genre x State Proportions
#' @description For the baseline crossed random-intercepts model (Model 1),
#'   draws posterior predictive replicates of engagement_state and compares
#'   observed vs. model-implied state proportions within each of the 20
#'   genres. Flags any genre where the observed proportion for a given
#'   state falls outside the 95% posterior predictive interval.

library(brms)
library(dplyr)
library(tidyr)
library(ggplot2)
library(haven)

dir.create("cache", showWarnings = FALSE)
dir.create("Plots", showWarnings = FALSE)

cat("Loading Model 1 (baseline crossed random intercepts)...\n")
fit <- readRDS("rds/model_brms_intercepts.rds")

# Reconstruct the exact analysis data frame used to fit Model 1
df_raw <- read_dta("dta/analysis_time_CCC.dta")
df_raw$id <- 1:nrow(df_raw)

genre_mapping <- list(
  g1=21, g2=22, g3=24, g4=39, g5=26, g6=36, g7=37, g8=23, g9=31, g10=27,
  g11=28, g12=40, g13=29, g14=30, g15=25, g16=32, g17=38, g18=33, g19=34, g20=35
)
genre_labels <- c(
  "Rock/Classic Rock", "Contemporary Pop", "Country", "Jazz", "Classical",
  "Rap/Hip Hop", "R&B/Blues", "Contemporary Rock", "Heavy Metal", "Folk",
  "Latin", "Reggae", "Oldies", "Bluegrass", "Opera",
  "Musicals", "New Age", "Easy Listening", "Gospel", "Swing/Big Band"
)

for (g in 1:20) {
  like_col <- paste0("like_music_genres_", genre_mapping[[paste0("g", g)]])
  df_raw[[paste0("like_g", g)]] <- ifelse(df_raw[[like_col]] >= 5 & df_raw[[like_col]] <= 7, 1, 0)
  df_raw[[paste0("listen_g", g)]] <- 0
  for (i in 1:10) {
    df_raw[[paste0("listen_g", g)]] <- df_raw[[paste0("listen_g", g)]] | (df_raw[[paste0("genre_final", i)]] == g)
  }
}

df_long <- df_raw %>%
  mutate(
    parent_educ = pmax(mom_educ, dad_educ, na.rm = TRUE),
    platform = case_when(
      grepl("spotify", stream_source, ignore.case = TRUE) ~ "Spotify",
      grepl("itunes", stream_source, ignore.case = TRUE) ~ "iTunes",
      grepl("winamp", stream_source, ignore.case = TRUE) ~ "Winamp",
      grepl("rotation", stream_source, ignore.case = TRUE) & !grepl("itunes|spotify|winamp", stream_source, ignore.case = TRUE) ~ "Free Recall",
      stream_source == "" ~ "Free Recall",
      TRUE ~ "Other"
    )
  ) %>%
  select(id, educ2, parent_educ, child_arts, agecat, female, income, race5, platform,
         starts_with("like_g"), starts_with("listen_g")) %>%
  pivot_longer(
    cols = matches("^(like|listen)_g\\d+"),
    names_to = c(".value", "genre_id"),
    names_pattern = "^([a-z]+)_g(\\d+)$"
  ) %>%
  mutate(
    id = as.factor(id),
    genre_id = as.factor(genre_id),
    race5 = as.factor(race5),
    platform = factor(platform, levels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other")),
    engagement_state = case_when(
      like == 0 & listen == 0 ~ "Neither",
      like == 0 & listen == 1 ~ "ListenOnly",
      like == 1 & listen == 0 ~ "LikeOnly",
      like == 1 & listen == 1 ~ "Both"
    ),
    engagement_state = factor(engagement_state, levels = c("Neither", "ListenOnly", "LikeOnly", "Both"))
  ) %>%
  filter(
    !is.na(engagement_state), !is.na(educ2), !is.na(parent_educ), !is.na(child_arts),
    !is.na(agecat), !is.na(female), !is.na(income), !is.na(race5), !is.na(platform)
  )

cat("Reconstructed sample:", nrow(df_long), "rows.\n")
stopifnot(nrow(df_long) == nobs(fit))

cat("Drawing posterior predictive replicates (this uses the full 4,000-draw posterior)...\n")
set.seed(4417)
ppd <- posterior_predict(fit, ndraws = 1000)  # ndraws x nobs matrix of predicted category indices
state_levels <- levels(df_long$engagement_state)

# Observed proportions per genre x state
obs_prop <- df_long %>%
  count(genre_id, engagement_state) %>%
  group_by(genre_id) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  rename(state = engagement_state)

# Predicted proportions per genre x state, per posterior draw
n_draws <- nrow(ppd)
pred_long <- vector("list", n_draws)
for (d in seq_len(n_draws)) {
  pred_states <- factor(state_levels[ppd[d, ]], levels = state_levels)
  tab <- table(df_long$genre_id, pred_states, dnn = c("genre_id", "state"))
  prop_tab <- prop.table(tab, margin = 1)
  pred_long[[d]] <- as.data.frame(prop_tab) %>%
    rename(prop = Freq) %>%
    mutate(draw = d)
}
pred_df <- bind_rows(pred_long)

pred_summary <- pred_df %>%
  group_by(genre_id, state) %>%
  summarise(
    pred_mean = mean(prop),
    pred_lo = quantile(prop, 0.025),
    pred_hi = quantile(prop, 0.975),
    .groups = "drop"
  )

ppc_df <- obs_prop %>%
  full_join(pred_summary, by = c("genre_id", "state")) %>%
  mutate(
    prop = ifelse(is.na(prop), 0, prop),
    outside_band = prop < pred_lo | prop > pred_hi,
    genre_label = genre_labels[as.integer(as.character(genre_id))]
  )

write.csv(ppc_df, "cache/posterior_predictive_check.csv", row.names = FALSE)

n_outside <- sum(ppc_df$outside_band, na.rm = TRUE)
n_total <- nrow(ppc_df)
cat(sprintf("\nPosterior predictive check: %d of %d genre-by-state observed proportions fall outside the 95%% posterior predictive interval.\n", n_outside, n_total))
print(ppc_df %>% filter(outside_band) %>% select(genre_label, state, prop, pred_mean, pred_lo, pred_hi))

p <- ggplot(ppc_df, aes(x = state, y = prop)) +
  geom_pointrange(aes(y = pred_mean, ymin = pred_lo, ymax = pred_hi), color = "grey50") +
  geom_point(aes(y = prop, color = outside_band), size = 2) +
  scale_color_manual(values = c("FALSE" = "black", "TRUE" = "red"), guide = "none") +
  facet_wrap(~ genre_label, ncol = 5) +
  labs(
    x = NULL, y = "Proportion",
    title = "Posterior Predictive Check: Observed vs. Predicted State Proportions",
    caption = "Grey intervals: 95% posterior predictive interval (Model 1). Black points: observed. Red points: observed proportion falls outside the interval."
  ) +
  theme_minimal(base_size = 8) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("Plots/PPC_Genre_State_Proportions.png", p, width = 6.5, height = 6, dpi = 300)
cat("Saved Plots/PPC_Genre_State_Proportions.png\n")
