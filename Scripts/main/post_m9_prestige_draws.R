#' @title Export Model 9 education-by-prestige draws for the three-panel figure
#' @description Loads the saved Model 9 fit once and writes the posterior draws
#'   of the education main effect and its prestige interaction for each of the
#'   three equations. The figure rebuilds the education odds ratio as a function
#'   of the College Preference Ratio from these draws, so it needs the joint
#'   posterior (the two coefficients are strongly correlated) rather than the
#'   summary table in cache/educ_prestige_test.csv.
#'
#'   Output: cache/m9_educ_prestige_draws.csv with columns draw, State, b_educ,
#'   b_int. All 10,000 kept draws are exported; the file is about 30,000 rows.

library(cmdstanr)
library(brms)
library(posterior)
library(dplyr)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading rds/model_brms_m9_educprestige.rds ...\n")
fit <- readRDS("rds/model_brms_m9_educprestige.rds")

dr <- as_draws_df(fit)
states <- c(ListenOnly = "Underclaiming",
            LikeOnly = "Overclaiming",
            Both = "Consistent Engagement")

out <- bind_rows(lapply(names(states), function(s) {
  b_educ <- dr[[paste0("b_mu", s, "_educ2")]]
  b_int <- dr[[paste0("b_mu", s, "_educ2:prestige_c")]]
  stopifnot(length(b_educ) == length(b_int), !is.null(b_educ), !is.null(b_int))
  data.frame(
    draw = seq_along(b_educ),
    State = states[[s]],
    b_educ = b_educ,
    b_int = b_int
  )
}))

write.csv(out, "cache/m9_educ_prestige_draws.csv", row.names = FALSE)
cat("Rows:", nrow(out), "draws per state:", nrow(out) / 3, "\n")
print(out |> group_by(State) |>
        summarise(b_educ = round(mean(b_educ), 3), b_int = round(mean(b_int), 3),
                  .groups = "drop") |> as.data.frame())
cat("Saved cache/m9_educ_prestige_draws.csv\n")
