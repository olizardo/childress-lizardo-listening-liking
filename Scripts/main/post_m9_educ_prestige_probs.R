#' @title Predicted probabilities by education and genre prestige (Model 9)
#' @description Turns the Model 9 interaction coefficients into the probability
#'   scale. The multinomial coefficients are log-odds against Neither, so three
#'   positive interactions do not by themselves imply that educated respondents
#'   are more likely to occupy all three engaged states in prestigious genres.
#'   This script computes the model's fitted probability of each state for every
#'   observed dyad and averages those probabilities within cells formed by the
#'   respondent's education category and the genre's prestige band.
#'
#'   No counterfactual covariate setting is used. Each dyad keeps its own values
#'   and the genre keeps its own random intercepts and slopes, so the cells
#'   describe the fitted probabilities the model assigns across the observed
#'   education-by-prestige space.
#'
#'   Output: cache/m9_predicted_probs_educ_prestige.csv with the posterior median
#'   and 95% credible interval of the cell mean probability for each state,
#'   education category and prestige band.

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)
library(posterior)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)

cat("Loading corrected model input...\n")
df_long <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    id = as.factor(id),
    genre_id = as.factor(genre_id),
    genre_name = genre_names[as.character(genre_id)],
    engagement_state = factor(as.integer(engagement_state), levels = 1:4,
                              labels = c("Neither", "ListenOnly", "LikeOnly", "Both")),
    race5 = factor(as.integer(race5), levels = 1:5,
                   labels = c("White", "Black", "Hispanic", "Asian", "Other/Mixed")),
    platform = factor(as.integer(platform), levels = 1:5,
                      labels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other"))
  )
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform), !any(is.na(df_long$genre_name)))

prest <- readRDS("rds/ame_genre_constrained.rds") |>
  select(genre_name, ratio_col)
stopifnot(nrow(prest) == 20)
p_mean <- mean(prest$ratio_col)
df_long <- df_long |>
  left_join(prest |> transmute(genre_name, ratio_col, prestige_c = ratio_col - p_mean),
            by = "genre_name")
stopifnot(!any(is.na(df_long$prestige_c)))

# Prestige bands follow Figure 9's three categories.
df_long <- df_long |>
  mutate(prestige_band = case_when(
    ratio_col < 1.0 ~ "Less Preferred (<1.0)",
    ratio_col <= 1.25 ~ "Slightly Preferred (1.0-1.25)",
    TRUE ~ "Preferred (>1.25)"
  ))
df_long$prestige_band <- factor(df_long$prestige_band,
                                 levels = c("Less Preferred (<1.0)",
                                            "Slightly Preferred (1.0-1.25)",
                                            "Preferred (>1.25)"))
df_long$educ2 <- as.integer(df_long$educ2)

cat("Education x band cell counts:\n")
print(table(df_long$educ2, df_long$prestige_band))

# Indicator matrix from dyads to cells (18 cells: 6 education x 3 bands).
cell <- interaction(df_long$educ2, df_long$prestige_band, drop = TRUE)
cell_levels <- levels(cell)
B <- model.matrix(~ 0 + cell)
colnames(B) <- cell_levels
cell_n <- colSums(B)

cat("Loading rds/model_brms_m9_educprestige.rds ...\n")
fit <- readRDS("rds/model_brms_m9_educprestige.rds")

n_draws <- tryCatch(posterior::ndraws(fit$fit),
                    error = function(e) posterior::ndraws(as_draws_rvars(fit)))
chunk <- 500
starts <- seq(1, n_draws, by = chunk)

acc <- list()
n_obs <- nrow(df_long)
for (k in seq_along(starts)) {
  idx <- starts[k]:min(starts[k] + chunk - 1, n_draws)
  cat(sprintf("[%s] posterior_epred draws %d-%d of %d\n",
              format(Sys.time(), "%H:%M:%S"), min(idx), max(idx), n_draws))
  ep <- posterior_epred(fit, draws = idx)
  dn <- dimnames(ep)
  # brms returns c(n_obs, n_cat, n_draws) for categorical models; fall back to
  # c(n_draws, n_obs, n_cat) if a future version reverses it.
  obs_first <- dim(ep)[1] == n_obs && length(dim(ep)) == 3 && dim(ep)[3] == length(idx)
  cat_dim <- if (obs_first) 2 else 3
  cat_names <- dn[[cat_dim]]
  stopifnot(length(cat_names) == 4)
  for (j in seq_along(cat_names)) {
    M <- if (obs_first) t(matrix(ep[, j, ], nrow = n_obs)) else matrix(ep[, , j], nrow = length(idx))
    stopifnot(ncol(M) == n_obs, nrow(M) == length(idx))
    cellmean <- (M %*% B) / rep(cell_n, each = nrow(M))
    colnames(cellmean) <- colnames(B)
    acc[[cat_names[j]]] <- rbind(acc[[cat_names[j]]], cellmean)
  }
  rm(ep); gc()
}

out <- bind_rows(lapply(names(acc), function(s) {
  M <- acc[[s]]
  data.frame(
    State = s,
    cell = colnames(M),
    median = apply(M, 2, median),
    lo = apply(M, 2, quantile, 0.025),
    hi = apply(M, 2, quantile, 0.975),
    n_dyads = cell_n
  )
})) |>
  mutate(
    educ2 = as.integer(sub("\\..*$", "", cell)),
    prestige_band = sub("^[0-9]+\\.", "", cell)
  ) |>
  mutate(State = recode(State, ListenOnly = "Underclaiming", LikeOnly = "Overclaiming",
                        Both = "Consistent Engagement", Neither = "Neither")) |>
  select(-cell)

write.csv(out, "cache/m9_predicted_probs_educ_prestige.csv", row.names = FALSE)
cat("\n===== PREDICTED PROBABILITIES BY EDUCATION AND PRESTIGE BAND =====\n")
print(out |> mutate(across(c(median, lo, hi), ~ round(.x, 4))) |>
        arrange(State, prestige_band, educ2) |> as.data.frame())
cat("Saved cache/m9_predicted_probs_educ_prestige.csv\n")
