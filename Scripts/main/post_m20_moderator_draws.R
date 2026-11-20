#' @title Export Model 20 moderator draws for the full-cross interaction table
#' @description Loads the saved Model 20 fit once and writes the posterior draws
#'   of every fixed term the full-cross table needs, for all three equations: the
#'   two capital-indicator main effects and their four genre-level interactions
#'   (arts x popularity, arts x prestige, education x popularity, education x
#'   prestige). Model 20 crosses both moderators with both exposures, so this is
#'   the only fit whose terms support a table with all four interactions.
#'
#'   brms orders interaction names by variable position in the formula, so every
#'   lookup tries both orders.
#'
#'   Output: cache/m20_moderator_draws.csv with columns draw, State, b_arts,
#'   b_arts_pop_int, b_arts_prest_int, b_educ, b_educ_pop_int, b_educ_prest_int.
#'   All 10,000 kept draws are exported.

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(posterior)
  library(dplyr)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading rds/model_brms_m20_full_cross.rds ...\n")
fit <- readRDS("rds/model_brms_m20_full_cross.rds")
dr <- as_draws_df(fit)

pick <- function(dr, cands) {
  hit <- cands[cands %in% names(dr)]
  if (length(hit) != 1) stop("expected exactly one of: ", paste(cands, collapse = ", "))
  as.numeric(dr[[hit]])
}

int_name <- function(dr, s, a, b) {
  pick(dr, c(paste0("b_", s, "_", a, ":", b), paste0("b_", s, "_", b, ":", a)))
}

states <- c(muListenOnly = "Underclaiming",
            muLikeOnly = "Overclaiming",
            muBoth = "Consistent Engagement")

out <- bind_rows(lapply(names(states), function(s) {
  b_arts <- pick(dr, paste0("b_", s, "_child_arts"))
  b_educ <- pick(dr, paste0("b_", s, "_educ2"))
  data.frame(
    draw = seq_along(b_arts),
    State = states[[s]],
    b_arts = b_arts,
    b_arts_pop_int = int_name(dr, s, "child_arts", "popularity_c"),
    b_arts_prest_int = int_name(dr, s, "child_arts", "prestige_c"),
    b_educ = b_educ,
    b_educ_pop_int = int_name(dr, s, "educ2", "popularity_c"),
    b_educ_prest_int = int_name(dr, s, "educ2", "prestige_c")
  )
}))

write.csv(out, "cache/m20_moderator_draws.csv", row.names = FALSE)
cat("Rows:", nrow(out), "draws per state:", nrow(out) / 3, "\n")
print(out |>
        group_by(State) |>
        summarise(across(starts_with("b_"), ~ round(mean(.x), 3)), .groups = "drop") |>
        as.data.frame())
cat("Saved cache/m20_moderator_draws.csv\n")
