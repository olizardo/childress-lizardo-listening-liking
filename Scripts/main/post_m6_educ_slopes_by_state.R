#' @title Export Model 6 genre education slopes for all three equations
#' @description Model 6 puts (1 + child_arts + educ2 | genre_id) into every
#'   equation, so each genre has an education slope for underclaiming and
#'   consistent engagement as well as the one for overclaiming that Figure 9
#'   uses. This script extracts all three sets with their posterior medians and
#'   95% bounds, so the three-panel education-by-prestige figure can show the
#'   free slopes behind each equation instead of only the overclaiming panel.
#'
#'   Output: cache/m6_educ_slope_by_state.csv with State, genre_name, ratio_col,
#'   slope_med, slope_lo, slope_hi. Slopes are on the educ2 log-odds scale, one
#'   unit of education; multiply by five and exponentiate for the full-range
#'   odds ratio used in the figures.

library(cmdstanr)
library(brms)
library(dplyr)
library(tidyr)
library(posterior)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

cat("Loading rds/model_brms_m6_educslopes.rds ...\n")
fit <- readRDS("rds/model_brms_m6_educslopes.rds")
prest <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col)
stopifnot(nrow(prest) == 20)

states <- c("muListenOnly" = "Underclaiming",
            "muLikeOnly" = "Overclaiming",
            "muBoth" = "Consistent Engagement")

# Random-effect column names look like r_genre_id__muLikeOnly[3,educ2], so the
# genre and term are parsed off the column names rather than through
# spread_draws, whose spec cannot be built from a string.
dr <- as_draws_matrix(fit)
cn <- colnames(dr)

out <- bind_rows(lapply(names(states), function(st) {
  cat("Extracting", st, "...\n")
  idx <- grep(paste0("^r_genre_id__", st, "\\["), cn)
  nm <- cn[idx]
  genre <- as.integer(sub(".*\\[([0-9]+),.*$", "\\1", nm))
  term <- sub(".*,([A-Za-z_0-9]+)\\]$", "\\1", nm)
  stopifnot(length(unique(genre)) == 20, all(term %in% c("Intercept", "child_arts", "educ2")))
  b_educ <- as.numeric(dr[, paste0("b_", st, "_educ2")])
  res <- lapply(1:20, function(g) {
    col_e <- which(genre == g & term == "educ2")
    stopifnot(length(col_e) == 1)
    total <- b_educ + as.numeric(dr[, idx[col_e]])
    data.frame(genre_name = genre_names[as.character(g)],
               slope_med = median(total),
               slope_lo = quantile(total, 0.025),
               slope_hi = quantile(total, 0.975))
  })
  bind_rows(res) |> mutate(State = states[[st]], .before = 1)
})) |>
  left_join(prest, by = "genre_name") |>
  mutate(State = factor(State, levels = c("Overclaiming", "Underclaiming",
                                          "Consistent Engagement"))) |>
  arrange(State, desc(ratio_col)) |>
  mutate(across(c(slope_med, slope_lo, slope_hi, ratio_col), ~ round(.x, 4)))

stopifnot(nrow(out) == 60, !any(is.na(out$ratio_col)))
write.csv(out, "cache/m6_educ_slope_by_state.csv", row.names = FALSE)
cat("\n===== GENRE EDUCATION SLOPES BY EQUATION =====\n")
print(out |> group_by(State) |>
        summarise(credibly_positive = sum(slope_lo > 0),
                  credibly_negative = sum(slope_hi < 0), .groups = "drop") |> as.data.frame())
cat("Saved cache/m6_educ_slope_by_state.csv\n")
