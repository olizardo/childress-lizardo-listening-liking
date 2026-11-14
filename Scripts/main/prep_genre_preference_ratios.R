#' @title Prestige and racial preference ratios by genre (corrected data)
#' @description Writes rds/ame_genre_constrained.rds, replacing the
#'   orphaned legacy rds/ame_genre_constrained.rds (no writing script; audit
#'   2026-11-11). For each of the 20 genres:
#'   ratio_col = P(likes genre | educ2 >= BA) / P(likes genre | educ2 <= HS grad)
#'   ratio_black = P(likes genre | race5 == Black) / P(likes genre | race5 == White)
#'   where "likes" = engagement_state in {LikeOnly, Both} in the corrected model
#'   input dta/analysis_model_input.dta. Ratios use person-level denominators
#'   (each person appears once per genre).

library(haven)
library(dplyr)

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

d <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    likes = as.integer(engagement_state) %in% c(3, 4),  # LikeOnly, Both
    educ2 = as.integer(educ2),
    race5 = as.integer(race5),
    genre_name = genre_names[as.character(genre_id)]
  )

stopifnot(!any(is.na(d$genre_name)))

d <- d |>
  mutate(
    college = !is.na(educ2) & educ2 >= 5,
    hs      = !is.na(educ2) & educ2 <= 2,  # HS grad or less, matching the manuscript
    black   = !is.na(race5) & race5 == 2,
    white   = !is.na(race5) & race5 == 1
  )
cat("Missing covariates dropped: educ2", sum(is.na(d$educ2)), "of", nrow(d),
    "; race5", sum(is.na(d$race5)), "\n")

ame <- d |>
  group_by(genre_name) |>
  summarise(
    p_college = mean(likes[college]),
    p_hs      = mean(likes[hs]),
    p_black   = mean(likes[black]),
    p_white   = mean(likes[white]),
    .groups = "drop"
  ) |>
  mutate(ratio_col = p_college / p_hs, ratio_black = p_black / p_white)

stopifnot(nrow(ame) == 20, !any(is.na(ame$ratio_col)), !any(is.na(ame$ratio_black)))

dir.create("rds", showWarnings = FALSE)
saveRDS(ame, "rds/ame_genre_constrained.rds")
write.csv(ame, "cache/ame_genre_ratios.csv", row.names = FALSE)
cat("Saved rds/ame_genre_constrained.rds\n")
print(ame)
