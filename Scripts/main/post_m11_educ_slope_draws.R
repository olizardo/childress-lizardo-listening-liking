#' @title Export genre-specific education slope draws from Model 11
#' @description Model 11 counterpart of post_m6_educ_slope_draws.R. Model 11
#'   keeps (1 + child_arts + educ2 | genre_id) on the two liking equations and
#'   drops the education slope only from the underclaiming equation, so the
#'   overclaiming education slope that Figure 6 plots is estimated in this fit.
#'   This script loads rds/model_brms_m11_educarts_liking.rds, adds the
#'   population slope to each genre's random slope in the Like Only equation,
#'   and writes all 10,000 post-warmup draws as a long table of draws by genre,
#'   so the figure can carry the same half-eye slabs as Figure 5.
#'
#'   Output: cache/m11_educ_slope_draws.csv with columns .draw, genre_name,
#'   genre_id and total_educ (log-odds scale). The figure script reads that file
#'   and applies exp(slope * 4) for the college-and-above versus high-school-or-less
#'   contrast.

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(dplyr)
  library(tidyr)
  library(tidybayes)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

cat("Loading M11 fit (arts and education slopes on the two liking equations)...\n")
fit <- readRDS("rds/model_brms_m11_educarts_liking.rds")

tb <- fit |>
  spread_draws(b_muLikeOnly_educ2, r_genre_id__muLikeOnly[genre_id, term]) |>
  filter(term == "educ2") |>
  mutate(
    genre_id = as.character(genre_id),
    genre_name = genre_names[genre_id],
    total_educ = b_muLikeOnly_educ2 + r_genre_id__muLikeOnly
  ) |>
  select(.draw, genre_id, genre_name, total_educ) |>
  arrange(.draw, genre_id)

stopifnot(n_distinct(tb$genre_name) == 20, !any(is.na(tb$total_educ)))
stopifnot(n_distinct(tb$.draw) == 10000, nrow(tb) == 200000)

write.csv(tb, "cache/m11_educ_slope_draws.csv", row.names = FALSE)
cat("Saved cache/m11_educ_slope_draws.csv (", nrow(tb), "rows,", n_distinct(tb$.draw), "draws )\n")
