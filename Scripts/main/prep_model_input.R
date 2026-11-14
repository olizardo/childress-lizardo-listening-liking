# ==============================================================================
# prep_model_input.R
#
# Shared data preparation for all corrected model fits. Single source of truth
# for the person-genre long dataset, replacing the copy-pasted construction
# blocks in the run_brms_*.R scripts.
#
# Corrections relative to the old inline blocks (2026-11-11 audit):
#   * genre_final1-10 and stream_source are taken from
#     dta/genresobjects_processed.dta (rebuild by Scripts/prep_artistgenre.R),
#     NOT from analysis_time_CCC.dta, whose genre_final values are corrupt
#     (cross-respondent shuffling; see AGENTS.md).
#   * Listening is coded NA-safe: listen_g = 1 iff the genre appears among the
#     respondent's filled slots (rowSums with na.rm). Respondents with no
#     filled slots at all (n = 25) have NA listen indicators for every genre
#     and drop out; respondents with 1-9 filled slots now contribute their
#     Neither and LikeOnly rows, which the old NA-propagating code dropped
#     (outcome-dependent selection).
#
# Output: dta/analysis_model_input.dta (long person-genre format).
# ==============================================================================

library(haven)
library(dplyr)
library(tidyr)

ccc <- read_dta("dta/analysis_time_CCC.dta")
go <- read_dta("dta/genresobjects_processed.dta")

stopifnot(!anyDuplicated(ccc$responseid), !anyDuplicated(go$responseid))

# --- splice in the rebuilt listening data -------------------------------------
gf_cols <- paste0("genre_final", 1:10)
idx <- match(ccc$responseid, go$responseid)
stopifnot(sum(is.na(idx)) == 0)
ccc[gf_cols] <- go[idx, gf_cols]
ccc$stream_source <- go$stream_source[idx]

ccc$id <- seq_len(nrow(ccc))

# --- liking / listening indicators --------------------------------------------
genre_mapping <- list(
  g1=21, g2=22, g3=24, g4=39, g5=26, g6=36, g7=37, g8=23, g9=31, g10=27,
  g11=28, g12=40, g13=29, g14=30, g15=25, g16=32, g17=38, g18=33, g19=34, g20=35
)

for (g in 1:20) {
  like_col <- paste0("like_music_genres_", genre_mapping[[paste0("g", g)]])
  ccc[[paste0("like_g", g)]] <-
    ifelse(!is.na(ccc[[like_col]]) & ccc[[like_col]] >= 5 & ccc[[like_col]] <= 7, 1L,
           ifelse(is.na(ccc[[like_col]]), NA_integer_, 0L))

  G <- as.data.frame(lapply(ccc[gf_cols], function(x) as.numeric(as.character(x))))
  ccc[[paste0("listen_g", g)]] <-
    ifelse(rowSums(!is.na(G)) > 0,
           as.integer(rowSums(G == g, na.rm = TRUE) > 0),
           NA_integer_)
}

# --- long format ---------------------------------------------------------------
df_long <- ccc %>%
  mutate(
    parent_educ = pmax(mom_educ, dad_educ, na.rm = TRUE),
    platform = case_when(
      grepl("spotify", stream_source, ignore.case = TRUE) ~ "Spotify",
      grepl("itunes", stream_source, ignore.case = TRUE) ~ "iTunes",
      grepl("winamp", stream_source, ignore.case = TRUE) ~ "Winamp",
      grepl("rotation", stream_source, ignore.case = TRUE) &
        !grepl("itunes|spotify|winamp", stream_source, ignore.case = TRUE) ~ "Free Recall",
      stream_source == "" ~ "Free Recall",
      TRUE ~ "Other"
    )
  ) %>%
  select(id, responseid, educ2, parent_educ, child_arts, agecat, female, income,
         race5, platform, starts_with("like_g"), starts_with("listen_g")) %>%
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
    !is.na(engagement_state),
    !is.na(educ2),
    !is.na(parent_educ),
    !is.na(child_arts),
    !is.na(agecat),
    !is.na(female),
    !is.na(income),
    !is.na(race5),
    !is.na(platform)
  )

write_dta(df_long, "dta/analysis_model_input.dta")

cat("Model input written to dta/analysis_model_input.dta\n")
cat("Rows:", nrow(df_long), "| Respondents:", n_distinct(df_long$id), "\n\n")
cat("Engagement-state shares:\n")
print(prop.table(table(df_long$engagement_state)))
cat("\nPlatform:\n")
print(table(df_long$platform[!duplicated(df_long$id)]))
