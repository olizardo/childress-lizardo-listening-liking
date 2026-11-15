#' @title Model 14 genre slopes by state for the per-genre points in Figures 11 and 12
#' @description Figures 11 and 12 plot the Model 14 interaction curves, and their
#'   free genre slope points used to come from Model 6. Model 14 carries the same
#'   genre random-effect structure as Model 11 ((1 + child_arts + educ2 |
#'   genre_id) in the overclaiming and consistent-engagement equations, intercept
#'   only in the underclaiming equation), so the points can come from the same fit
#'   as the curves. The underclaiming equation has no slopes and so contributes
#'   no points.
#'
#'   Output: cache/m14_arts_slope_by_state.csv and cache/m14_educ_slope_by_state.csv
#'   with State, genre_name, ratio_col, slope_med, slope_lo, slope_hi.

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(dplyr)
  library(tidyr)
  library(posterior)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

cat("Loading rds/model_brms_m14_both_mods_restricted.rds ...\n")
fit <- readRDS("rds/model_brms_m14_both_mods_restricted.rds")
prest <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col)
stopifnot(nrow(prest) == 20)

states <- c("muLikeOnly" = "Overclaiming",
            "muBoth" = "Consistent Engagement")

dr <- as_draws_matrix(fit)
cn <- colnames(dr)
q <- function(x, p) as.numeric(quantile(x, p))

out <- bind_rows(lapply(names(states), function(st) {
  idx <- grep(paste0("^r_genre_id__", st, "\\["), cn)
  nm <- cn[idx]
  genre <- as.integer(sub(".*\\[([0-9]+),.*$", "\\1", nm))
  term <- sub(".*,([A-Za-z_0-9]+)\\]$", "\\1", nm)
  stopifnot(length(unique(genre)) == 20,
            setequal(unique(term), c("Intercept", "child_arts", "educ2")))
  b_arts <- as.numeric(dr[, paste0("b_", st, "_child_arts")])
  b_educ <- as.numeric(dr[, paste0("b_", st, "_educ2")])
  bind_rows(lapply(1:20, function(g) {
    art <- b_arts + as.numeric(dr[, idx[which(genre == g & term == "child_arts")]])
    edu <- b_educ + as.numeric(dr[, idx[which(genre == g & term == "educ2")]])
    data.frame(State = states[[st]],
               genre_name = genre_names[as.character(g)],
               arts_slope_med = q(art, 0.5), arts_slope_lo = q(art, 0.025),
               arts_slope_hi = q(art, 0.975),
               educ_slope_med = q(edu, 0.5), educ_slope_lo = q(edu, 0.025),
               educ_slope_hi = q(edu, 0.975))
  }))
})) |>
  left_join(prest, by = "genre_name") |>
  arrange(State, desc(ratio_col))

stopifnot(nrow(out) == 40, !any(is.na(out$ratio_col)))
write.csv(
  out |> select(State, genre_name, ratio_col, slope_med = arts_slope_med,
                slope_lo = arts_slope_lo, slope_hi = arts_slope_hi),
  "cache/m14_arts_slope_by_state.csv", row.names = FALSE
)
write.csv(
  out |> select(State, genre_name, ratio_col, slope_med = educ_slope_med,
                slope_lo = educ_slope_lo, slope_hi = educ_slope_hi),
  "cache/m14_educ_slope_by_state.csv", row.names = FALSE
)

cat("\n===== FREE GENRE SLOPES BY STATE (paper Model 4) =====\n")
print(as.data.frame(out |> select(State, genre_name, ratio_col, arts_slope_med, educ_slope_med)))
cat("\nSaved cache/m14_arts_slope_by_state.csv and cache/m14_educ_slope_by_state.csv\n")
