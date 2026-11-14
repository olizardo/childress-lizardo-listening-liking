#' @title Bayesian Categorical Model, Quadratic Arts Exposure (Model 7)
#' @description Direct test of H2B, which predicts that overclaiming is
#'   greatest at middling cultural capital rather than rising monotonically.
#'   The existing evidence on H2B uses the three education tiers; this model
#'   tests the same shape on the primary capital measure by adding a squared
#'   term to childhood arts exposure. Otherwise the specification matches the
#'   corrected Model 1 (crossed random intercepts, no genre slopes).
#'
#'   Arts exposure is centered before squaring (arts_c = child_arts - mean,
#'   arts_c2 = arts_c^2). Uncentered, child_arts and its square correlate at
#'   about 0.98 across the 1-7 range, which makes sampling needlessly hard; the
#'   curvature coefficient is unchanged by centering. Under H2B the quadratic
#'   term should be negative and credible, putting the vertex inside the range
#'   rather than at its end. A post-processing step can recover the vertex as
#'   -b_linear / (2 * b_quad) in centered units and convert back by adding the
#'   mean of child_arts.
#'
#'   Output: rds/model_brms_m7_artsquad.rds, rds/waic_m7_artsquad.rds,
#'   cache/diagnostics_m7.txt. Compare against M1 v2 with a paired
#'   loo_compare in a separate process (never raw dWAIC).

library(cmdstanr)
library(brms)
library(haven)
library(dplyr)

cmdstanr::set_cmdstan_path("~/.cmdstan/cmdstan-2.33.1")

cat("Loading corrected model input...\n")
df_long <- read_dta("dta/analysis_model_input.dta") |>
  mutate(
    id = as.factor(id),
    genre_id = as.factor(genre_id),
    engagement_state = factor(
      as.integer(engagement_state),
      levels = 1:4,
      labels = c("Neither", "ListenOnly", "LikeOnly", "Both")
    ),
    race5 = factor(
      as.integer(race5),
      levels = 1:5,
      labels = c("White", "Black", "Hispanic", "Asian", "Other/Mixed")
    ),
    platform = factor(
      as.integer(platform),
      levels = 1:5,
      labels = c("Free Recall", "Spotify", "iTunes", "Winamp", "Other")
    )
  )

arts_mean <- mean(df_long$child_arts, na.rm = TRUE)
df_long <- df_long |>
  mutate(
    arts_c  = child_arts - arts_mean,
    arts_c2 = arts_c^2
  )
cat("child_arts mean used for centering:", round(arts_mean, 4),
    "| range of arts_c:", paste(round(range(df_long$arts_c), 2), collapse = " to "), "\n")
cat("cor(arts_c, arts_c2) =", round(cor(df_long$arts_c, df_long$arts_c2), 4), "\n")
cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

bf_quad <- bf(
  engagement_state ~ educ2 + parent_educ + arts_c + arts_c2 + agecat + female + income + race5 + platform +
    (1 | id) +
    (1 | genre_id)
)

priors_quad <- c(
  prior(normal(0, 1.5), class = "b", dpar = "muListenOnly"),
  prior(normal(0, 1.5), class = "b", dpar = "muLikeOnly"),
  prior(normal(0, 1.5), class = "b", dpar = "muBoth"),
  prior(normal(0, 2), class = "Intercept", dpar = "muListenOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muLikeOnly"),
  prior(normal(0, 2), class = "Intercept", dpar = "muBoth"),
  prior(exponential(1), class = "sd", dpar = "muListenOnly"),
  prior(exponential(1), class = "sd", dpar = "muLikeOnly"),
  prior(exponential(1), class = "sd", dpar = "muBoth")
)

dir.create("rds", showWarnings = FALSE)
dir.create("cache", showWarnings = FALSE)

cat("Sampling Model 7 (quadratic arts exposure) via cmdstanr...\n")
fit <- brm(
  formula = bf_quad,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_quad,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 6000,
  warmup = 2500,
  seed = 6184,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.995, max_treedepth = 13),
  file = "rds/model_brms_m7_artsquad",
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m7.txt")
cat("== Model 7 (quadratic arts exposure), corrected data ==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 13), "\n")
cat("\nArts terms (centered):\n")
print(fixef(fit)[grep("arts_c", rownames(fixef(fit))), ])
sink()
cat(readLines("cache/diagnostics_m7.txt"), sep = "\n")

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m7_artsquad.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m7_artsquad.rds")

# H2B verdict: sign and credibility of the curvature, plus the vertex in the
# original 1-7 metric (arts_c = child_arts - arts_mean).
dr <- as_draws_df(fit)
h2b <- bind_rows(lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(s) {
  b1 <- dr[[paste0("b_", s, "_arts_c")]]
  b2 <- dr[[paste0("b_", s, "_arts_c2")]]
  vx <- arts_mean - b1 / (2 * b2)
  data.frame(
    State = gsub("^mu", "", s),
    b_linear = round(mean(b1), 3),
    b_quadratic = round(mean(b2), 3),
    quad_CrI_2.5 = round(quantile(b2, 0.025), 3),
    quad_CrI_97.5 = round(quantile(b2, 0.975), 3),
    p_quad = round(2 * min(mean(b2 <= 0), mean(b2 >= 0)), 4),
    vertex = round(median(vx), 2),
    vertex_CrI_2.5 = round(quantile(vx, 0.025), 2),
    vertex_CrI_97.5 = round(quantile(vx, 0.975), 2),
    vertex_in_range = round(mean(vx > 1 & vx < 7), 3)
  )
}))
write.csv(h2b, "cache/h2b_quadratic_arts.csv", row.names = FALSE)
cat("\n===== H2B: QUADRATIC ARTS EXPOSURE =====\n")
print(h2b)
cat("Saved cache/h2b_quadratic_arts.csv\n")
cat("Done: rds/model_brms_m7_artsquad.rds\n")
