#' @title Residualized genre intercepts versus educational prestige
#' @description Descriptive companion to the genre-intercept results (Figure 1).
#'   Takes the M1 v2 genre random intercepts, correlates each equation's
#'   intercepts with the genre-level College Preference Ratio (educational
#'   prestige, from rds/ame_genre_constrained.rds), then residualizes the
#'   intercepts on the genre's engagement base (share of respondents who like
#'   the genre, or share who listen to it) draw by draw before correlating
#'   again. Answers whether prestige predicts where overclaiming concentrates
#'   once a genre's popularity is held fixed, which is the "disproportionately"
#'   claim in H1B. Reported p-values are two-sided Bayesian tail probabilities
#'   on the Pearson correlation across the twenty genres.
#'   Output: cache/residualized_intercept_correlations.csv
#'   Requires: rds/model_brms_m1_corrected_v2.rds (14,000 draws), never load
#'   another brmsfit in the same process.

library(haven)
library(dplyr)
library(brms)

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

d <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    eng = as.integer(engagement_state),  # 1 Neither, 2 ListenOnly, 3 LikeOnly, 4 Both
    genre_name = genre_names[as.character(genre_id)]
  )
stopifnot(!any(is.na(d$genre_name)))

shares <- d |>
  group_by(genre_name) |>
  summarise(
    listened_share = mean(eng %in% c(2, 4)),
    liked_share    = mean(eng %in% c(3, 4)),
    .groups = "drop"
  )
stopifnot(nrow(shares) == 20)

ame <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col)

fit <- readRDS("rds/model_brms_m1_corrected_v2.rds")
re_all <- ranef(fit, summary = FALSE)
gnm <- grep("genre", names(re_all), ignore.case = TRUE)
re <- if (length(gnm) == 1) re_all[[gnm]] else re_all[[1]]
cat("ranef draws array dim:", paste(dim(re), collapse = " x "), "\n")
stopifnot(dim(re)[2] == 20)

q <- function(v) c(median(v), quantile(v, c(0.025, 0.975)))
p_two <- function(v) 2 * min(mean(v <= 0), mean(v >= 0))

res_rows <- list()

for (cat in dimnames(re)[[3]]) {
  if (grepl("sigma", cat, fixed = TRUE)) next
  ic <- re[, , cat]
  gnames <- genre_names[dimnames(re)[[2]]]
  stopifnot(all(gnames %in% shares$genre_name))

  sh <- shares[match(gnames, shares$genre_name), ]
  pr <- ame$ratio_col[match(gnames, ame$genre_name)]
  stopifnot(!any(is.na(pr)))

  ic_t <- ic[seq(1, dim(ic)[1], by = 10), ]  # thin to 1,400 draws

  # raw: intercepts versus prestige, no base adjustment
  r_raw   <- apply(ic_t, 1, function(y) cor(y, pr))
  rho_raw <- apply(ic_t, 1, function(y) cor(y, pr, method = "spearman"))

  for (base in c("listened_share", "liked_share")) {
    x <- sh[[base]]
    # residualize each draw's intercepts on the engagement base, then correlate
    res <- apply(ic_t, 1, function(y) {
      b <- coef(lm(y ~ x))
      y - b[1] - b[2] * x
    })
    r_res   <- apply(res, 2, function(e) cor(e, pr))
    rho_res <- apply(res, 2, function(e) cor(e, pr, method = "spearman"))

    res_rows[[paste(cat, base)]] <- data.frame(
      equation = cat,
      base = base,
      n_draws = length(r_raw),
      r_raw = q(r_raw)[1], r_raw_lo = q(r_raw)[2], r_raw_hi = q(r_raw)[3],
      p_raw = p_two(r_raw),
      rho_raw = q(rho_raw)[1], rho_raw_lo = q(rho_raw)[2], rho_raw_hi = q(rho_raw)[3],
      r_resid = q(r_res)[1], r_resid_lo = q(r_res)[2], r_resid_hi = q(r_res)[3],
      p_resid = p_two(r_res),
      rho_resid = q(rho_res)[1], rho_resid_lo = q(rho_res)[2], rho_resid_hi = q(rho_res)[3]
    )
  }
}

out <- bind_rows(res_rows)
dir.create("cache", showWarnings = FALSE)
write.csv(out, "cache/residualized_intercept_correlations.csv", row.names = FALSE)
print(out, digits = 3)
cat("\nSaved cache/residualized_intercept_correlations.csv\n")
