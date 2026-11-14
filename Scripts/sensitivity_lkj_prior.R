#' @title Sensitivity Analysis: LKJ Prior Concentration on Genre-Level Correlation
#' @description Adapted to the corrected pipeline (2026-11-13). Model 5
#'   (crossed random slopes) estimates a genre-level intercept-slope
#'   correlation from only J=20 genre clusters. This script refits the
#'   corrected Model 5 specification twice more with alternative lkj()
#'   concentration priors -- lkj(1) (uniform over correlation matrices) and
#'   lkj(4) (stronger shrinkage toward zero correlation) -- holding
#'   everything else fixed, and compares the LikeOnly intercept-slope
#'   correlation against rds/model_brms_m5_corrected.rds (lkj(2)).
#'   Sampling settings match the corrected M5 fit (iter 4000 / warmup 1500,
#'   adapt_delta 0.97).
#'   Output: rds/model_brms_m5_lkj1_corrected.rds,
#'   rds/model_brms_m5_lkj4_corrected.rds, cache/sensitivity_lkj.csv

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

cat("Sample size:", nrow(df_long), "rows across", n_distinct(df_long$id), "respondents.\n")
stopifnot(is.factor(df_long$race5), is.factor(df_long$platform))  # response coding guard: race5/platform must be factors

n_cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK",
                                unset = as.integer(Sys.getenv("NSLOTS", unset = 16))))
n_chains <- 4
threads_per_chain <- max(1, floor(n_cpus / n_chains))
cat("CPUs:", n_cpus, "| chains:", n_chains, "| threads/chain:", threads_per_chain, "\n")

bf_slopes <- bf(
  engagement_state ~ educ2 + parent_educ + child_arts + agecat + female + income + race5 + platform +
    (1 | id) +
    (1 + child_arts | genre_id)
)

fit_with_lkj <- function(eta, out_file, seed) {
  priors <- c(
    prior(normal(0, 1.5), class = "b", dpar = "muListenOnly"),
    prior(normal(0, 1.5), class = "b", dpar = "muLikeOnly"),
    prior(normal(0, 1.5), class = "b", dpar = "muBoth"),
    prior(normal(0, 2), class = "Intercept", dpar = "muListenOnly"),
    prior(normal(0, 2), class = "Intercept", dpar = "muLikeOnly"),
    prior(normal(0, 2), class = "Intercept", dpar = "muBoth"),
    prior(exponential(1), class = "sd", dpar = "muListenOnly"),
    prior(exponential(1), class = "sd", dpar = "muLikeOnly"),
    prior(exponential(1), class = "sd", dpar = "muBoth"),
    set_prior(paste0("lkj(", eta, ")"), class = "cor")
  )
  brm(
    formula = bf_slopes,
    data = df_long,
    family = categorical(link = "logit", refcat = "Neither"),
    prior = priors,
    chains = n_chains,
    cores = n_chains,
    threads = threading(threads_per_chain),
    iter = 4000,
    warmup = 1500,
    control = list(adapt_delta = 0.97, max_treedepth = 13),
    backend = "cmdstanr",
    file = out_file,
    file_refit = "on_change",
    seed = seed
  )
}

dir.create("rds", showWarnings = FALSE)
dir.create("cache", showWarnings = FALSE)

cat("Fitting corrected Model 5 variant with lkj(1) (uniform prior)...\n")
fit_lkj1 <- fit_with_lkj(1, "rds/model_brms_m5_lkj1_corrected", seed = 3081)

cat("Fitting corrected Model 5 variant with lkj(4) (stronger shrinkage toward 0)...\n")
fit_lkj4 <- fit_with_lkj(4, "rds/model_brms_m5_lkj4_corrected", seed = 6650)

cat("Loading corrected Model 5 (lkj(2)) fit for comparison...\n")
fit_lkj2 <- readRDS("rds/model_brms_m5_corrected.rds")

extract_cor <- function(fit, label) {
  draws <- brms::as_draws_df(fit)
  cor_col <- grep("^cor_genre_id__muLikeOnly_Intercept__muLikeOnly_child_arts$", names(draws), value = TRUE)
  if (length(cor_col) == 0) {
    cor_col <- grep("^cor_genre_id.*LikeOnly.*Intercept.*child_arts$|^cor_genre_id.*LikeOnly.*child_arts.*Intercept$", names(draws), value = TRUE)
  }
  if (length(cor_col) == 0) return(data.frame(Prior = label, Column = NA, Mean = NA, SD = NA, CrI_2.5 = NA, CrI_97.5 = NA))
  x <- draws[[cor_col[1]]]
  data.frame(
    Prior = label,
    Column = cor_col[1],
    Mean = round(mean(x), 3),
    SD = round(sd(x), 3),
    CrI_2.5 = round(quantile(x, 0.025), 3),
    CrI_97.5 = round(quantile(x, 0.975), 3)
  )
}

comparison <- bind_rows(
  extract_cor(fit_lkj1, "LKJ(1) - uniform"),
  extract_cor(fit_lkj2, "LKJ(2) - corrected M5"),
  extract_cor(fit_lkj4, "LKJ(4) - shrink toward 0")
)

write.csv(comparison, "cache/sensitivity_lkj.csv", row.names = FALSE)
cat("\n===== GENRE-LEVEL LIKEONLY INTERCEPT-SLOPE CORRELATION ACROSS LKJ PRIORS =====\n")
print(comparison)
cat("================================================================================\n")
cat("Saved to cache/sensitivity_lkj.csv\n")
