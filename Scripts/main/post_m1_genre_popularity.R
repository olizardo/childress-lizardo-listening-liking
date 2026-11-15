#' @title Genre popularity estimated from the baseline fit
#' @description Model-based popularity for the twenty genres, taken from the
#'   random-intercepts baseline (Model 1 v2), which carries no genre random
#'   slopes. Estimating popularity here rather than from the Model 3 fit keeps
#'   the popularity values free of the LKJ prior that ties a genre's intercept
#'   to its slope, so they can be correlated with Model 3's slopes without
#'   inducing dependence through the prior.
#'
#'   Popularity is one minus the fitted Neither probability for a genre,
#'   averaged over all of that genre's person-genre rows, i.e. the model-based
#'   counterpart of the descriptive share of dyads with playlist engagement. All
#'   four state probabilities are kept so the file also supports checks against
#'   the liking share.
#'
#'   cache/m1_genre_popularity_draws.csv  draw x genre, 1,000 draws of the four
#'                                        average state probabilities
#'   cache/m1_genre_popularity.csv        per genre summary and the descriptive
#'                                        share of dyads not in Neither
#'
#'   posterior_epred is computed one genre at a time (1,433 rows x 1,000 draws x
#'   4 categories), which keeps the array small; the whole-slice call would
#'   materialise about 1 GB per level on this 14 GB machine.

suppressMessages({
  library(cmdstanr)
  library(brms)
  library(haven)
  library(dplyr)
})

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

genre_names <- c(
  "1" = "Swing/Big Band", "2" = "Bluegrass", "3" = "R&B/Blues", "4" = "Classic Rock",
  "5" = "Classical", "6" = "Contemporary Pop", "7" = "Contemporary Rock", "8" = "Country",
  "9" = "Easy Listening", "10" = "Folk", "11" = "Gospel", "12" = "Heavy Metal",
  "13" = "Jazz", "14" = "Latin", "15" = "Musicals", "16" = "New Age",
  "17" = "Oldies", "18" = "Opera", "19" = "Rap/Hip Hop", "20" = "Reggae"
)
state_levels <- c("Neither", "ListenOnly", "LikeOnly", "Both")

df_long <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    id = as.factor(id),
    genre_id = as.factor(genre_id),
    engagement_state = factor(as.integer(engagement_state), levels = 1:4,
                              labels = state_levels),
    race5 = factor(as.integer(race5), levels = 1:5,
                   labels = c("White", "Black", "Hispanic", "Asian", "Other/Mixed")),
    platform = factor(as.integer(platform), levels = 1:5,
                      labels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other"))
  )
# The baseline fit saw only four platform levels (no "Other" respondents), so
# unused levels are dropped here; brms rejects new levels in newdata.
df_long <- droplevels(df_long)
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))
cat("platform levels:", paste(levels(df_long$platform), collapse = ", "), "\n")
cat("race5 levels:", paste(levels(df_long$race5), collapse = ", "), "\n")

cat("Loading rds/model_brms_m1_corrected_v2.rds ...\n")
fit <- readRDS("rds/model_brms_m1_corrected_v2.rds")

# Descriptive counterpart: share of dyads that are not in Neither.
descr <- df_long |>
  group_by(genre_id) |>
  summarise(share_engaged = mean(engagement_state != "Neither"),
            share_liked = mean(engagement_state %in% c("LikeOnly", "Both")),
            n_rows = n(), .groups = "drop") |>
  mutate(genre_name = genre_names[as.character(as.integer(genre_id))])

ndraws_use <- 1000
rows <- list()
for (g in levels(df_long$genre_id)) {
  nd <- df_long[df_long$genre_id == g, ]
  ep <- posterior_epred(fit, newdata = nd, ndraws = ndraws_use, re_formula = NULL)
  # Dimension order is checked rather than assumed: the older note that
  # observations come first was wrong for this fit.
  if (dim(ep)[1] != ndraws_use) ep <- aperm(ep, c(3, 1, 2))
  stopifnot(dim(ep)[1] == min(ndraws_use, nrow(as_draws_matrix(fit))),
            dim(ep)[2] == nrow(nd), dim(ep)[3] == 4)
  avg <- apply(ep, c(1, 3), mean)          # draws x states, averaged over rows
  rows[[g]] <- data.frame(
    .draw = seq_len(nrow(avg)),
    genre_id = as.integer(g),
    genre_name = genre_names[g],
    p_neither = avg[, "Neither"],
    p_listen = avg[, "ListenOnly"],
    p_like = avg[, "LikeOnly"],
    p_both = avg[, "Both"]
  )
  cat("genre", g, genre_names[g], "done\n")
  rm(ep, avg); gc(verbose = FALSE)
}
pop_draws <- bind_rows(rows) |>
  mutate(popularity = 1 - p_neither)
stopifnot(nrow(pop_draws) == 20 * 1000, !any(is.na(pop_draws$popularity)))

write.csv(pop_draws, "cache/m1_genre_popularity_draws.csv", row.names = FALSE)

q <- function(x, p) as.numeric(quantile(x, p))
pop_summary <- pop_draws |>
  group_by(genre_name) |>
  summarise(
    pop_med = q(popularity, 0.5), pop_lo = q(popularity, 0.025), pop_hi = q(popularity, 0.975),
    p_neither_med = q(p_neither, 0.5),
    p_like_med = q(p_like, 0.5),
    p_both_med = q(p_both, 0.5),
    .groups = "drop"
  ) |>
  left_join(descr |> select(genre_name, share_engaged, share_liked, n_rows), by = "genre_name") |>
  arrange(desc(pop_med))
write.csv(pop_summary, "cache/m1_genre_popularity.csv", row.names = FALSE)

cat("\n===== MODEL-BASED GENRE POPULARITY (1 - Neither) =====\n")
print(as.data.frame(pop_summary))
cat("\ncor(model popularity, descriptive engaged share) =",
    round(cor(pop_summary$pop_med, pop_summary$share_engaged), 3), "\n")
cat("cor(model popularity, descriptive liked share)  =",
    round(cor(pop_summary$pop_med, pop_summary$share_liked), 3), "\n")
cat("\nSaved cache/m1_genre_popularity_draws.csv, cache/m1_genre_popularity.csv\n")
