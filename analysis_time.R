library(haven)
library(dplyr)
library(tidyr)
library(stringr)

# ==============================================================================
# ANALYSIS TIME
# ==============================================================================

df <- read_dta("analysis_time_CCC.dta")

# Create IDs
df$id <- 1:nrow(df)

# Volume Calculations
# genre_final1 to genre_final10 columns need to be combined
genre_cols <- paste0("genre_final", 1:10)

# count filled slots
df$nfilled <- rowSums(!is.na(df[, genre_cols]))

# Count distinct genres per person
df_long <- df %>% 
  select(id, nfilled, all_of(genre_cols)) %>%
  pivot_longer(cols = starts_with("genre_final"), values_to = "genre") %>%
  filter(!is.na(genre))

distinct_counts <- df_long %>%
  group_by(id) %>%
  summarise(volume_listen_all = n_distinct(genre))

df <- df %>% left_join(distinct_counts, by = "id") %>%
  mutate(volume_listen_all = replace_na(volume_listen_all, 0),
         volume_listen_ten = ifelse(nfilled == 10, volume_listen_all, NA))

# Composition
df$composition_listen_all <- 0
for (i in 1:10) {
  col <- paste0("genre_final", i)
  df$composition_listen_all <- df$composition_listen_all + 
    ifelse(df[[col]] %in% c(5, 18, 13, 4, 3), 1, 0) -
    ifelse(df[[col]] %in% c(12, 19, 16, 9, 20), 1, 0)
  
  df$composition_listen_all[is.na(df[[col]])] <- df$composition_listen_all[is.na(df[[col]])] # handle NAs gracefully
}
df$composition_listen_ten <- ifelse(df$nfilled == 10, df$composition_listen_all, NA)

# Gaps
df$z_volume_listen_ten <- scale(df$volume_listen_ten)
df$z_mu_genrelike_count <- scale(df$mu_genrelike_count)
df$gap_volume_listen_like <- df$z_volume_listen_ten - df$z_mu_genrelike_count

# Liking Sets (Exclude Pop vs Include Pop)
# Exclude Pop
white_expop_cols <- paste0("like_music_genres_", c(21,22,39,26,37,23,31,27,40,25,32,38,33))
nonwhite_cols <- paste0("like_music_genres_", c(24,28,29,30,34,35))

df$like_expop_white <- rowMeans(df[, white_expop_cols], na.rm = TRUE)
df$like_expop_nonwhite <- rowMeans(df[, nonwhite_cols], na.rm = TRUE)
df$like_expop_diff <- df$like_expop_nonwhite - df$like_expop_white

# Include Pop
white_incpop_cols <- c(white_expop_cols, "like_music_genres_36")
df$like_incpop_white <- rowMeans(df[, white_incpop_cols], na.rm = TRUE)
df$like_incpop_nonwhite <- df$like_expop_nonwhite
df$like_incpop_diff <- df$like_incpop_nonwhite - df$like_incpop_white

# Listening Sets
df$listen_expop_nonwhite <- 0
df$listen_incpop_nonwhite <- 0
df$listen_expop_white <- 0
df$listen_incpop_white <- 0

for (i in 1:10) {
  val <- df[[paste0("genre_final", i)]]
  df$listen_expop_nonwhite <- df$listen_expop_nonwhite + ifelse(val %in% c(3,11,13,14,19,20), 1, 0)
  df$listen_incpop_nonwhite <- df$listen_incpop_nonwhite + ifelse(val %in% c(3,11,13,14,19,20), 1, 0)
  
  df$listen_expop_white <- df$listen_expop_white + ifelse(val %in% c(1,2,4,5,7,8,9,10,12,15,16,17,18), 1, 0)
  df$listen_incpop_white <- df$listen_incpop_white + ifelse(val %in% c(1,2,4,5,6,7,8,9,10,12,15,16,17,18), 1, 0)
}
# handle NAs properly
df <- df %>% mutate_at(vars(starts_with("listen_")), ~replace_na(., 0))

df$listen_expop_diff <- df$listen_expop_nonwhite - df$listen_expop_white
df$listen_incpop_diff <- df$listen_incpop_nonwhite - df$listen_incpop_white

# Standardized race gaps
df$racegap_expop <- scale(df$listen_expop_diff) - scale(df$like_expop_diff)
df$racegap_incpop <- scale(df$listen_incpop_diff) - scale(df$like_incpop_diff)

# Overclaim Index
genre_mapping <- list(
  g1=21, g2=22, g3=24, g4=39, g5=26, g6=36, g7=37, g8=23, g9=31, g10=27,
  g11=28, g12=40, g13=29, g14=30, g15=25, g16=32, g17=38, g18=33, g19=34, g20=35
)

# calculate binary like (5-7) and binary listen
for (g in 1:20) {
  like_col <- paste0("like_music_genres_", genre_mapping[[paste0("g", g)]])
  df[[paste0("like_g", g)]] <- ifelse(df[[like_col]] >= 5 & df[[like_col]] <= 7, 1, 0)
  
  # did they listen?
  df[[paste0("listen_g", g)]] <- 0
  for (i in 1:10) {
    df[[paste0("listen_g", g)]] <- df[[paste0("listen_g", g)]] | (df[[paste0("genre_final", i)]] == g)
  }
  
  # Calculate overclaiming: they like it (1) but didn't listen to it (0)
  df[[paste0("overclaim_g", g)]] <- ifelse(df[[paste0("like_g", g)]] == 1 & df[[paste0("listen_g", g)]] == 0, 1, 0)
}

# Total number of genres a person overclaimed
overclaim_cols <- paste0("overclaim_g", 1:20)
df$total_overclaim <- rowSums(df[, overclaim_cols], na.rm = TRUE)

# Pivot data to long format for mixed effects analysis
df_long_overclaim <- df %>%
  select(id, educ2, child_arts, agecat, income, female, urban_rural2, race5, social,
         starts_with("like_g"), starts_with("listen_g"), starts_with("overclaim_g")) %>%
  pivot_longer(
    cols = matches("^(like|listen|overclaim)_g\\d+"),
    names_to = c(".value", "genre_id"),
    names_pattern = "^([a-z]+)_g(\\d+)$"
  ) %>%
  mutate(genre_id = as.factor(genre_id))

write_dta(df_long_overclaim, "analysis_time_long.dta")

# Linear models (examples matching the Stata regressions)
# You can run these natively:
# summary(lm(gap_volume_listen_like ~ educ2 + child_arts + agecat + income + female + urban_rural2 + as.factor(race5), data=df))
# summary(lm(racegap_incpop ~ educ2 + child_arts + agecat + income + female + urban_rural2 + as.factor(race5) + social, data=df))

write_dta(df, "analysis_time_R_processed.dta")
