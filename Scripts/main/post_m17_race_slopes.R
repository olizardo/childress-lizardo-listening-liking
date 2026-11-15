#' @title Model 17 race-specific genre slopes: does the race effect vary by genre?
#' @description Model 17 adds a genre random slope on the Black dummy in the
#'   overclaiming equation and on the Hispanic dummy in the underclaiming
#'   equation. This script reports whether those two fixed coefficients are
#'   constants or vary across the twenty genres, in four pieces:
#'
#'   cache/m17_race_slope_summary.csv   fixed coefficient, random-slope SD and
#'                                      correlation with the genre intercept,
#'                                      additivity spread, per state
#'   cache/m17_genre_race_slopes.csv    per genre: total slope (fixed + random),
#'                                      95% CrI, probability of a positive sign
#'
#'   "Total slope" is the genre's coefficient on its race dummy, so a genre with
#'   a total of 0.40 raises that group's odds of the state by exp(0.40) relative
#'   to White respondents in the same genre.
#'
#'   The random slopes enter equations where the fixed race terms are already
#'   estimated on the race5 factor, so the fixed part stays interpretable as the
#'   coefficient at the average genre.

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

cat("Loading rds/model_brms_m17_race_slopes.rds ...\n")
fit <- readRDS("rds/model_brms_m17_race_slopes.rds")

dr <- as_draws_matrix(fit)
cn <- colnames(dr)
n_draw <- nrow(dr)
cat("Draws:", n_draw, "\n")

# ---- Draw-level per-genre slopes ------------------------------------------
# One state per random slope, with the dummy name in the term position.
states <- list(
  Overclaiming = list(state = "muLikeOnly", dummy = "black_d",
                      fixed = "b_muLikeOnly_race5Black"),
  Underclaiming = list(state = "muListenOnly", dummy = "hisp_d",
                       fixed = "b_muListenOnly_race5Hispanic")
)

get_state <- function(state, dummy, fixed) {
  idx <- grep(paste0("^r_genre_id__", state, "\\["), cn)
  nm <- cn[idx]
  genre <- as.integer(sub(".*\\[([0-9]+),.*$", "\\1", nm))
  term <- sub(".*,([A-Za-z_0-9]+)\\]$", "\\1", nm)
  # Names printed so a mismatch in the slope term is visible in the job log.
  cat(state, "random terms:", paste(sort(unique(term)), collapse = ", "), "\n")
  # The fixed race coefficient is resolved by pattern rather than assumed, since
  # brms factor naming was unverified for this fit. Printed for the log.
  if (!fixed %in% cn) {
    cand <- grep(paste0("^b_", state, "_race5.*", sub("_d$", "", dummy)),
                 cn, value = TRUE, ignore.case = TRUE)
    cat("fixed name", fixed, "absent; candidates:",
        paste(cand, collapse = ", "), "\n")
    fixed <- cand[1]
  }
  stopifnot(length(unique(genre)) == 20,
            setequal(unique(term), c("Intercept", dummy)),
            length(fixed) == 1, !is.na(fixed))
  cat(state, "fixed coefficient:", fixed, "\n")
  b_fixed <- as.numeric(dr[, fixed])
  out <- lapply(1:20, function(g) {
    u0 <- as.numeric(dr[, idx[which(genre == g & term == "Intercept")]])
    u1 <- as.numeric(dr[, idx[which(genre == g & term == dummy)]])
    data.frame(.draw = seq_len(n_draw), genre_id = g, u0 = u0, u1 = u1,
               fixed = b_fixed, total = b_fixed + u1)
  })
  bind_rows(out) |> mutate(genre_name = genre_names[as.character(genre_id)])
}

cat("Extracting overclaiming (Black) slopes...\n")
like <- get_state(states$Overclaiming$state, states$Overclaiming$dummy,
                  states$Overclaiming$fixed)
cat("Extracting underclaiming (Hispanic) slopes...\n")
listen <- get_state(states$Underclaiming$state, states$Underclaiming$dummy,
                    states$Underclaiming$fixed)

stopifnot(!any(is.na(like$total)), !any(is.na(listen$total)),
          nrow(like) == n_draw * 20, nrow(listen) == n_draw * 20)

# ---- Random-slope SD and correlation, read off the draws ------------------
# brms names these sd_genre_id__<state>_<term> and
# cor_genre_id__<state>__<term1>__<term2>; both orders are tried for the
# correlation because the order follows the formula.
pick <- function(patterns) {
  hit <- unlist(lapply(patterns, function(p) grep(p, cn, value = TRUE)))
  hit <- unique(hit)
  if (length(hit) == 0) return(rep(NA_real_, n_draw))
  as.numeric(dr[, hit[1]])
}

q <- function(x, p) as.numeric(quantile(x, p, na.rm = TRUE))
summ <- function(x) {
  data.frame(Median = round(median(x, na.rm = TRUE), 3),
             CrI_2.5 = round(q(x, 0.025), 3),
             CrI_97.5 = round(q(x, 0.975), 3),
             p_bayes = round(2 * min(mean(x <= 0, na.rm = TRUE),
                                     mean(x >= 0, na.rm = TRUE)), 4))
}

one_row <- function(label, x) cbind(Quantity = label, summ(x))

rows <- list()
for (nm in names(states)) {
  st <- states[[nm]]$state
  du <- states[[nm]]$dummy
  d <- if (nm == "Overclaiming") like else listen
  sd_slope <- pick(paste0("^sd_genre_id__", st, "_", du, "$"))
  cor_islope <- pick(c(paste0("^cor_genre_id__", st, "_Intercept__", st, "_", du, "$"),
                       paste0("^cor_genre_id__", st, "_", du, "__", st, "_Intercept$"),
                       paste0("^cor_genre_id__", st, "__Intercept__", du, "$"),
                       paste0("^cor_genre_id__", st, "__", du, "__Intercept$"),
                       paste0("^cor_genre_id.*", st, ".*(Intercept.*", du, "|", du, ".*Intercept)$")))
  sd_int <- pick(paste0("^sd_genre_id__", st, "_Intercept$"))
  # Spread of the per-genre totals against the model's own random-slope SD.
  tot_spread <- d |> group_by(.draw) |> summarise(s = sd(total), .groups = "drop") |> pull(s)

  rows[[length(rows) + 1]] <- rbind(
    cbind(State = nm, one_row("Fixed coefficient (average genre)", d$fixed)),
    cbind(State = nm, one_row("Random-slope SD", sd_slope)),
    cbind(State = nm, one_row("Intercept-slope correlation", cor_islope)),
    cbind(State = nm, one_row("Genre intercept SD", sd_int)),
    cbind(State = nm, one_row("SD of the 20 total slopes", tot_spread)),
    cbind(State = nm, one_row("Smallest total slope", d |> group_by(.draw) |> summarise(x = min(total)) |> pull(x))),
    cbind(State = nm, one_row("Largest total slope", d |> group_by(.draw) |> summarise(x = max(total)) |> pull(x)))
  )
}
summary_out <- bind_rows(rows)
write.csv(summary_out, "cache/m17_race_slope_summary.csv", row.names = FALSE)

# ---- Per-genre totals ------------------------------------------------------
genre_out <- bind_rows(
  like |> mutate(State = "Overclaiming"),
  listen |> mutate(State = "Underclaiming")
) |>
  group_by(State, genre_name) |>
  summarise(
    fixed = q(fixed, 0.5),
    slope_med = q(total, 0.5), slope_lo = q(total, 0.025), slope_hi = q(total, 0.975),
    pd_positive = mean(total > 0),
    or_med = q(exp(total), 0.5),
    .groups = "drop"
  ) |>
  arrange(State, desc(slope_med))
write.csv(genre_out, "cache/m17_genre_race_slopes.csv", row.names = FALSE)

# Draw-level totals for the half-eye figure, the same shape as
# cache/m11_arts_slope_draws.csv so figure_14 can reuse the Figure 5 idiom.
# The race contrast is binary, so the odds ratio is exp(slope) with no multiplier.
slope_draws <- bind_rows(
  like |> mutate(State = "Overclaiming"),
  listen |> mutate(State = "Underclaiming")
) |>
  select(State, .draw, genre_name, total_slope = total) |>
  mutate(odds_ratio = exp(total_slope))
write.csv(slope_draws, "cache/m17_genre_race_slope_draws.csv", row.names = FALSE)
cat("Rows written:", nrow(slope_draws), "\n")

# ---- Console summary ------------------------------------------------------
cat("\n===== M17 RACE SLOPE SUMMARY =====\n")
print(as.data.frame(summary_out))
cat("\n===== PER-GENRE SLOPES =====\n")
print(as.data.frame(genre_out))
for (nm in c("Overclaiming", "Underclaiming")) {
  g <- genre_out |> filter(State == nm)
  cat("\n", nm, ": ", sum(g$slope_lo > 0), " genres credibly above zero, ",
      sum(g$slope_hi < 0), " credibly below zero, ",
      sum(g$slope_lo <= 0 & g$slope_hi >= 0), " not distinguishable\n", sep = "")
}
cat("\nSaved cache/m17_race_slope_summary.csv, cache/m17_genre_race_slopes.csv\n")
