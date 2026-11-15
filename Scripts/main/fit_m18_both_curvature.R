#' @title Bayesian Categorical Model, Quadratic Arts Exposure and Education (Model 18)
#' @description Model 7's quadratic arts term plus a quadratic term in
#'   educational attainment, on the corrected baseline structure (crossed random
#'   intercepts, no genre slopes). Model 7 tests curvature in the primary
#'   capital measure alone; this fit asks whether the two capital indicators are
#'   curvilinear on the same scale, and whether the arts curvature survives once
#'   education is allowed its own.
#'
#'   Both predictors are centered before squaring (arts_c = child_arts - mean,
#'   educ_c = educ2 - mean), since uncentered the linear and quadratic terms
#'   correlate near 0.98 across the observed range. Centering leaves the
#'   curvature coefficient unchanged and keeps the vertex recoverable as
#'   mean - b_linear / (2 * b_quad) in the original metric.
#'
#'   Sampling settings, priors and covariates match fit_m7_arts_quadratic.R, so a
#'   paired WAIC comparison isolates the two added curvature terms.
#'
#'   Output: rds/model_brms_m18_both_curvature.rds,
#'   rds/waic_m18_both_curvature.rds, cache/diagnostics_m18.txt,
#'   cache/m18_curvature.csv.

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
educ_mean <- mean(df_long$educ2, na.rm = TRUE)
df_long <- df_long |>
  mutate(
    arts_c  = child_arts - arts_mean,
    arts_c2 = arts_c^2,
    educ_c  = educ2 - educ_mean,
    educ_c2 = educ_c^2
  )
cat("centering means | arts:", round(arts_mean, 4), "| educ2:", round(educ_mean, 4), "\n")
cat("cor(arts_c, arts_c2) =", round(cor(df_long$arts_c, df_long$arts_c2), 4),
    "| cor(educ_c, educ_c2) =", round(cor(df_long$educ_c, df_long$educ_c2), 4), "\n")
cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

# Written in the main formula, so both curvature pairs reach all three equations.
bf_both_quad <- bf(
  engagement_state ~ arts_c + arts_c2 + educ_c + educ_c2 +
    parent_educ + agecat + female + income + race5 + platform +
    (1 | id) +
    (1 | genre_id)
)

priors_both_quad <- c(
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

cat("Sampling Model 18 (quadratic arts exposure and education) via cmdstanr...\n")
fit <- brm(
  formula = bf_both_quad,
  data = df_long,
  family = categorical(link = "logit", refcat = "Neither"),
  prior = priors_both_quad,
  chains = n_chains,
  cores = n_chains,
  threads = threading(threads_per_chain),
  iter = 6000,
  warmup = 2500,
  seed = 2071,
  backend = "cmdstanr",
  control = list(adapt_delta = 0.995, max_treedepth = 13),
  file = "rds/model_brms_m18_both_curvature",
  file_refit = "always"
)

print(summary(fit))

sink("cache/diagnostics_m18.txt")
cat("== Model 18 (quadratic arts exposure and education), corrected data ==\n")
print(max(rhat(fit)))
cat("min bulk ESS ratio:", min(neff_ratio(fit)), "\n")
cat("Divergences:", sum(nuts_params(fit, "divergent__")$Value != 0), "\n")
cat("Max treedepth hits:", sum(nuts_params(fit, "treedepth__")$Value >= 13), "\n")
cat("\nCentered curvature and linear terms:\n")
print(fixef(fit)[grep("arts_c|educ_c", rownames(fixef(fit))), ])
sink()
cat(readLines("cache/diagnostics_m18.txt"), sep = "\n")

cat("Computing WAIC...\n")
waic_res <- waic(fit)
saveRDS(waic_res, "rds/waic_m18_both_curvature.rds")
fit$criteria$waic <- waic_res
saveRDS(fit, "rds/model_brms_m18_both_curvature.rds")

# Curvature verdict for both predictors: sign, credibility, vertex in the
# original metric, and the share of draws with the vertex inside the range.
dr <- as_draws_df(fit)
quad_table <- function(var, mean_used, lo, hi) {
  bind_rows(lapply(c("muListenOnly", "muLikeOnly", "muBoth"), function(s) {
    b1 <- dr[[paste0("b_", s, "_", var, "_c")]]
    b2 <- dr[[paste0("b_", s, "_", var, "_c2")]]
    vx <- mean_used - b1 / (2 * b2)
    data.frame(
      Variable = var,
      State = gsub("^mu", "", s),
      b_linear = round(mean(b1), 3),
      b_quadratic = round(mean(b2), 4),
      quad_CrI_2.5 = round(quantile(b2, 0.025), 4),
      quad_CrI_97.5 = round(quantile(b2, 0.975), 4),
      p_quad = round(2 * min(mean(b2 <= 0), mean(b2 >= 0)), 4),
      vertex = round(median(vx), 2),
      vertex_CrI_2.5 = round(quantile(vx, 0.025), 2),
      vertex_CrI_97.5 = round(quantile(vx, 0.975), 2),
      vertex_in_range = round(mean(vx > lo & vx < hi), 3)
    )
  }))
}
curv <- bind_rows(
  quad_table("arts", arts_mean, 1, 7),
  quad_table("educ", educ_mean, 1, 6)
)
write.csv(curv, "cache/m18_curvature.csv", row.names = FALSE)
cat("\n===== MODEL 18: CURVATURE IN ARTS EXPOSURE AND EDUCATION =====\n")
print(curv)
cat("Saved cache/m18_curvature.csv\n")
cat("Done: rds/model_brms_m18_both_curvature.rds\n")
