# Post-processing for Models 13 and 14: extract the two prestige interactions
# (arts and education) from the saved fits and write the tidy tables.
#
# The fit scripts looked the interactions up as "educ2:prestige_c", but brms
# named the term "prestige_c:educ2" (it orders the interaction by variable
# position in the formula), so the education rows came out as NA. This script
# tries both name orders and fails loudly with the available column names if
# neither exists.
#
# Usage: Rscript Scripts/main/post_both_moderators_extract.R            # both fits
#        Rscript Scripts/main/post_both_moderators_extract.R m13        # one fit
#
# Loads one fit at a time; run it with 40 GB or more.
suppressMessages({
  library(brms)
  library(dplyr)
  library(posterior)
})

runs <- list(
  m13 = list(fit = "rds/model_brms_m13_both_moderators.rds",
             csv = "cache/both_moderators_test.csv",
             label = "Model 13 (arts and education moderated by prestige, 120 slopes)"),
  m14 = list(fit = "rds/model_brms_m14_both_mods_restricted.rds",
             csv = "cache/both_moderators_restricted_test.csv",
             label = "Model 14 (same interactions, 80 slopes)")
)

args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  stopifnot(all(args %in% names(runs)))
  runs <- runs[args]
}

# Genre prestige, joined by name exactly as in the fit scripts.
prest <- readRDS("rds/ame_genre_constrained.rds") |> select(genre_name, ratio_col)
stopifnot(nrow(prest) == 20)
rng_p <- diff(range(prest$ratio_col))

draw_col <- function(dr, st, v) {
  cands <- c(paste0("b_", st, "_", v, ":prestige_c"),
             paste0("b_", st, "_prestige_c:", v))
  hit <- cands[cands %in% names(dr)]
  if (!length(hit)) {
    stop("no interaction column for ", st, " x ", v, ". Columns present: ",
         paste(grep(paste0("^b_", st, "_.*prestige"), names(dr), value = TRUE),
               collapse = ", "), call. = FALSE)
  }
  list(draws = dr[[hit[1]]], term = hit[1])
}

extract_one <- function(fit_path) {
  cat("Loading", fit_path, "...\n")
  fit <- readRDS(fit_path)
  dr <- as_draws_df(fit)
  stopifnot(grepl("categorical", fit$family$family, ignore.case = TRUE))

  rows <- lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(st) {
    bind_rows(lapply(c("child_arts", "educ2"), function(v) {
      b_int <- draw_col(dr, st, v)
      b_main <- dr[[paste0("b_", st, "_", v)]]
      data.frame(
        State = gsub("^mu", "", st),
        Moderator = v,
        slope_at_mean_prestige = round(mean(b_main), 3),
        interaction = round(mean(b_int$draws), 3),
        int_CrI_2.5 = round(quantile(b_int$draws, 0.025), 3),
        int_CrI_97.5 = round(quantile(b_int$draws, 0.975), 3),
        p_interaction = round(2 * min(mean(b_int$draws <= 0), mean(b_int$draws >= 0)), 4),
        # multiplicative change in the exposure effect across the observed
        # prestige range, from the same posterior draws
        multiplier_across_prestige_range = round(exp(mean(b_int$draws) * rng_p), 3),
        term = b_int$term
      )
    }))
  })
  rm(fit, dr); invisible(gc())
  bind_rows(rows)
}

for (nm in names(runs)) {
  r <- runs[[nm]]
  out <- extract_one(r$fit)
  write.csv(out, r$csv, row.names = FALSE)
  cat("\n===== ", r$label, " =====\n", sep = "")
  print(out)
  cat("Saved", r$csv, "\n")
}
