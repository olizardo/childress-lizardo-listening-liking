#' @title Export Model 19 moderator draws for the arts and education interaction figures
#' @description Loads the saved Model 19 fit once and writes the posterior draws
#'   of the arts-exposure main effect with its POPULARITY interaction and the
#'   education main effect with its College Preference Ratio interaction, for
#'   all three equations. Model 19 is paper Model 4 (the restricted 80-slope
#'   structure with matched moderators), so the interaction estimates here are
#'   the ones the paper reports. Figure 8 rebuilds the arts odds ratio as a
#'   function of genre popularity and Figure 9 the education odds ratio as a
#'   function of the College Preference Ratio from these draws, so they need
#'   the joint posterior of each main effect and its interaction rather than
#'   the summary table.
#'
#'   brms orders interaction names by variable position in the formula, so the
#'   lookups try both orders of each interaction.
#'
#'   Output: cache/m19_moderator_draws.csv with columns draw, State, b_arts,
#'   b_arts_pop_int, b_educ, b_educ_ratio_int. All 10,000 kept draws are exported.

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(posterior)
  library(dplyr)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading rds/model_brms_m19_poparts_eduprestige.rds ...\n")
fit <- readRDS("rds/model_brms_m19_poparts_eduprestige.rds")
dr <- as_draws_df(fit)

pick <- function(dr, cands) {
  hit <- cands[cands %in% names(dr)]
  if (length(hit) != 1) stop("expected exactly one of: ", paste(cands, collapse=", "))
  as.numeric(dr[[hit]])
}

states <- c(muListenOnly = "Underclaiming",
            muLikeOnly = "Overclaiming",
            muBoth = "Consistent Engagement")

out <- bind_rows(lapply(names(states), function(s) {
  b_arts <- pick(dr, c(paste0("b_", s, "_child_arts")))
  b_arts_int <- pick(dr, c(paste0("b_", s, "_child_arts:popularity_c"),
                           paste0("b_", s, "_popularity_c:child_arts")))
  b_educ <- pick(dr, c(paste0("b_", s, "_educ2")))
  b_educ_int <- pick(dr, c(paste0("b_", s, "_educ2:prestige_c"),
                           paste0("b_", s, "_prestige_c:educ2")))
  data.frame(draw = seq_along(b_arts), State = states[[s]],
             b_arts = b_arts, b_arts_pop_int = b_arts_int,
             b_educ = b_educ, b_educ_ratio_int = b_educ_int)
}))

write.csv(out, "cache/m19_moderator_draws.csv", row.names = FALSE)
cat("Rows:", nrow(out), "draws per state:", nrow(out) / 3, "\n")
print(out |>
        group_by(State) |>
        summarise(b_arts = round(mean(b_arts), 3), arts_pop_int = round(mean(b_arts_pop_int), 3),
                  b_educ = round(mean(b_educ), 3), educ_ratio_int = round(mean(b_educ_ratio_int), 3),
                  .groups = "drop") |> as.data.frame())
cat("Saved cache/m19_moderator_draws.csv\n")
