#' @title Anti-tautology checks for the Model 6 education slopes (Figure 9)
#' @description The educational prestige measure (College Preference Ratio) is
#'   built from liking shares by education, and the Model 6 education slopes on
#'   the y-axis of Figure 9 are education gradients of overclaiming. A reviewer
#'   could therefore suspect that the strong correlation reported in the text
#'   is true by definition. This script assembles the checks that rule that out.
#'
#'   Check 1 (external ordering). Correlate the genre education slopes with the
#'   racial preference ratio, which is built from a race contrast and shares no
#'   variable with education. A mechanical education artifact would not track
#'   the race ordering; an education-specific gradient should be near zero
#'   against it.
#'
#'   Check 2 (listening channel). Overclaiming is liking without listening, so
#'   the education slope of the LikeOnly-vs-Neither contrast contains information
#'   the College Preference Ratio does not: the genre's listening gradient. If
#'   the slope were pinned by the liking gradient alone, the listening gradient
#'   would carry no weight conditional on the liking gradient. It does.
#'
#'   Inputs (both local, no fit required):
#'     cache/m6_educ_genre_slopes.csv  (from Scripts/main/check_education_prestige_correlation.R)
#'     dta/analysis_model_input.dta
#'   Output:
#'     cache/m6_educ_slope_antitautology_checks.csv

suppressMessages({
  library(haven)
  library(dplyr)
})

slopes <- read.csv("cache/m6_educ_genre_slopes.csv", stringsAsFactors = FALSE)
stopifnot(nrow(slopes) == 20)

# Education slope expressed as the full-range odds ratio (five steps from less
# than high school to graduate degree), matching Figure 9.
slopes <- slopes |>
  mutate(or_educ = exp(educ_slope_med * 5))

# --- Check 1: correlation with an ordering not built from education ----------
r_race <- cor(slopes$or_educ, slopes$ratio_black, method = "pearson")
rho_race <- cor(slopes$or_educ, slopes$ratio_black, method = "spearman")

set.seed(5271)
bs <- replicate(5000, {
  i <- sample.int(20, 20, replace = TRUE)
  cor(slopes$or_educ[i], slopes$ratio_black[i], method = "pearson")
})
bs_ci <- quantile(bs, c(0.025, 0.975), na.rm = TRUE)

# Comparator on the same medians: the education-built ratio.
r_cpr <- cor(slopes$or_educ, slopes$ratio_col, method = "pearson")

# --- Check 2: raw liking and listening gradients per genre -------------------
genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

d <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    likes   = as.integer(engagement_state) %in% c(3, 4),  # LikeOnly, Both
    listens = as.integer(engagement_state) %in% c(2, 4),  # ListenOnly, Both
    educ2   = as.integer(educ2),
    college = educ2 >= 5,
    hs      = educ2 <= 2,
    genre_name = genre_names[as.character(genre_id)]
  )

grads <- d |>
  group_by(genre_name) |>
  summarise(
    p_like_c = mean(likes[college], na.rm = TRUE),
    p_like_h = mean(likes[hs], na.rm = TRUE),
    p_lis_c  = mean(listens[college], na.rm = TRUE),
    p_lis_h  = mean(listens[hs], na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    like_grad = log((p_like_c / (1 - p_like_c)) / (p_like_h / (1 - p_like_h))),
    lis_grad  = log((p_lis_c / (1 - p_lis_c)) / (p_lis_h / (1 - p_lis_h)))
  )

m <- left_join(grads, slopes, by = "genre_name")
stopifnot(!any(is.na(m$like_grad)), !any(is.na(m$lis_grad)), nrow(m) == 20)

fit_lis <- lm(educ_slope_med ~ like_grad + lis_grad, data = m)
coef_lis <- summary(fit_lis)$coefficients

# --- Report ------------------------------------------------------------------
out <- data.frame(
  Statistic = c(
    "Pearson r (educ slope vs racial preference ratio)",
    "Spearman rho (educ slope vs racial preference ratio)",
    "Bootstrap 95% CI lower (educ slope vs racial preference ratio)",
    "Bootstrap 95% CI upper (educ slope vs racial preference ratio)",
    "Pearson r (educ slope vs College Preference Ratio, medians)",
    "Pearson r (educ slope vs raw liking gradient)",
    "Pearson r (educ slope vs raw listening gradient)",
    "Partial coefficient on listening gradient (slope ~ like_grad + lis_grad)",
    "SE on listening gradient"
  ),
  Value = round(c(
    r_race, rho_race, bs_ci[1], bs_ci[2],
    r_cpr,
    cor(m$educ_slope_med, m$like_grad),
    cor(m$educ_slope_med, m$lis_grad),
    coef_lis["lis_grad", "Estimate"],
    coef_lis["lis_grad", "Std. Error"]
  ), 3),
  check.names = FALSE
)

dir.create("cache", showWarnings = FALSE)
write.csv(out, "cache/m6_educ_slope_antitautology_checks.csv", row.names = FALSE)
print(out)
cat("\nSaved cache/m6_educ_slope_antitautology_checks.csv\n")
