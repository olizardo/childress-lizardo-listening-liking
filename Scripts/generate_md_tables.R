dir.create("cache", showWarnings = FALSE)

library(brms)
library(tidybayes)
library(dplyr)
library(knitr)
options(knitr.kable.NA = "—")

m_intercepts <- readRDS("rds/model_brms_intercepts.rds")
draws <- as_draws_df(m_intercepts)

# Asymptotic Posterior Wald-Type Statistic
#
# NOTE ON INTERPRETATION: this is NOT a classical frequentist Wald test.
# It treats the posterior mean and posterior covariance of a parameter
# block as if they were the mean/covariance of an asymptotically normal
# sampling distribution, forms the squared Mahalanobis distance from the
# null origin, and refers that statistic to a chi-square reference
# distribution to obtain an approximate p-value. This is a reasonable
# large-sample approximation ONLY to the extent that each block's joint
# posterior is itself approximately multivariate normal. See
# compute_posterior_normality_check() below, which reports univariate
# skewness/excess kurtosis for every coefficient entering each block so
# that departures from normality (which would invalidate the chi-square
# reference distribution) are visible rather than assumed away.
predictor_defs <- list(
  list(id = "child_arts",  label = "Childhood Arts Exposure",     pattern = "child_arts"),
  list(id = "platform",    label = "Platform (Streaming Source)", pattern = "platform"),
  list(id = "race5",       label = "Race / Ethnicity",            pattern = "race5"),
  list(id = "educ2",       label = "Education",                   pattern = "educ2"),
  list(id = "agecat",      label = "Age Category",                pattern = "agecat"),
  list(id = "parent_educ", label = "Parental Education",          pattern = "parent_educ"),
  list(id = "income",      label = "Household Income",            pattern = "income"),
  list(id = "female",      label = "Gender ID (Woman)",           pattern = "female")
)

compute_bayesian_wald <- function(draws, predictor_defs) {
  b_cols <- grep("^b_", names(draws), value = TRUE)
  b_cols_no_int <- grep("Intercept", b_cols, value = TRUE, invert = TRUE)
  
  b_mat <- as.matrix(draws[, b_cols_no_int])
  mu_b <- colMeans(b_mat)
  sigma_b <- cov(b_mat)
  
  results <- lapply(predictor_defs, function(p) {
    matched_cols <- grep(p$pattern, b_cols_no_int, value = TRUE)
    if (p$id == "educ2") {
      matched_cols <- matched_cols[!grepl("parent_educ", matched_cols)]
    }
    if (length(matched_cols) == 0) return(NULL)
    
    sub_mu <- mu_b[matched_cols]
    sub_sigma <- sigma_b[matched_cols, matched_cols]
    
    wald_stat <- as.numeric(t(sub_mu) %*% solve(sub_sigma) %*% sub_mu)
    df_val <- length(matched_cols)
    p_val <- pchisq(wald_stat, df = df_val, lower.tail = FALSE)
    
    data.frame(
      Predictor = p$label,
      Chi_Square = wald_stat,
      DF = df_val,
      P_Value = p_val,
      stringsAsFactors = FALSE
    )
  })
  
  df_res <- bind_rows(results) %>%
    arrange(desc(Chi_Square)) %>%
    mutate(
      P_Value = ifelse(P_Value < 0.001, "< 0.001", sprintf("%.3f", P_Value)),
      Chi_Square = round(Chi_Square, 2)
    ) %>%
    select(Predictor, Chi_Square, DF, P_Value)
  
  return(df_res)
}

# Companion diagnostic: for every coefficient entering a predictor block,
# report univariate skewness and excess kurtosis of its marginal posterior.
# The chi-square reference distribution used above is only appropriate to
# the extent that each block's joint posterior is approximately
# multivariate normal; skewness near 0 and excess kurtosis near 0 for every
# constituent coefficient is a necessary (not sufficient) condition for
# that approximation to be reasonable. Large departures should be reported
# alongside the Wald-type statistic rather than silently assumed away.
skewness <- function(x) {
  n <- length(x); m <- mean(x); s <- sd(x)
  (sum((x - m)^3) / n) / s^3
}
excess_kurtosis <- function(x) {
  n <- length(x); m <- mean(x); s <- sd(x)
  (sum((x - m)^4) / n) / s^4 - 3
}

compute_posterior_normality_check <- function(draws, predictor_defs) {
  b_cols <- grep("^b_", names(draws), value = TRUE)
  b_cols_no_int <- grep("Intercept", b_cols, value = TRUE, invert = TRUE)

  results <- lapply(predictor_defs, function(p) {
    matched_cols <- grep(p$pattern, b_cols_no_int, value = TRUE)
    if (p$id == "educ2") {
      matched_cols <- matched_cols[!grepl("parent_educ", matched_cols)]
    }
    if (length(matched_cols) == 0) return(NULL)

    per_coef <- lapply(matched_cols, function(cn) {
      x <- draws[[cn]]
      data.frame(
        Predictor = p$label,
        Coefficient = cn,
        Skewness = round(skewness(x), 3),
        Excess_Kurtosis = round(excess_kurtosis(x), 3)
      )
    })
    bind_rows(per_coef)
  })

  df_res <- bind_rows(results) %>%
    mutate(
      Flag = ifelse(abs(Skewness) > 0.5 | abs(Excess_Kurtosis) > 1, "Non-normal", "OK")
    )
  return(df_res)
}

wald_df <- compute_bayesian_wald(draws, predictor_defs)
sink("cache/table1_wald.md")
cat("**Table 1: Joint Variable Importance (Asymptotic Posterior Wald-Type Statistic)**\n\n")
print(kable(wald_df, format = "pipe"))
sink()

normality_df <- compute_posterior_normality_check(draws, predictor_defs)
sink("cache/table1b_wald_normality_check.md")
cat("**Table 1b: Posterior Normality Diagnostics for Wald-Type Statistic Inputs**\n\n")
cat("Skewness and excess kurtosis of each coefficient's marginal posterior; ")
cat("large departures from 0 on either measure indicate the chi-square ")
cat("reference distribution used in Table 1 may not be well approximated.\n\n")
print(kable(normality_df %>% select(Predictor, Coefficient, Skewness, Excess_Kurtosis, Flag), format = "pipe"))
sink()

n_flagged <- sum(normality_df$Flag == "Non-normal")
cat(sprintf("Posterior normality check: %d of %d block coefficients flagged as non-normal (|skew|>0.5 or |excess kurtosis|>1).\n",
            n_flagged, nrow(normality_df)))

# Equation Tables
extract_eq <- function(draws, state) {
  prefix <- paste0("b_mu", state, "_")
  state_cols <- grep(paste0("^", prefix), names(draws), value = TRUE)
  
  pred_map <- data.frame(col = state_cols, stringsAsFactors = FALSE) %>%
  mutate(
    raw_name = gsub(prefix, "", col),
    clean_name = case_when(
      raw_name == "Intercept" ~ "Intercept",
      raw_name == "educ2" ~ "Education",
      raw_name == "parent_educ" ~ "Parental Education",
      raw_name == "child_arts" ~ "Childhood Arts Exposure",
      raw_name == "agecat" ~ "Age Category",
      raw_name == "female" ~ "Gender ID (Woman)",
      raw_name == "income" ~ "Household Income",
      raw_name == "race52" ~ "Race: Black",
      raw_name == "race53" ~ "Race: Hispanic",
      raw_name == "race54" ~ "Race: Asian",
      raw_name == "race55" ~ "Race: Other/Mixed",
      raw_name == "platformSpotify" ~ "Platform: Spotify",
      raw_name == "platformiTunes" ~ "Platform: iTunes",
      raw_name == "platformWinamp" ~ "Platform: Winamp",
      TRUE ~ raw_name
    )
  )
  
  summaries <- lapply(pred_map$col, function(c) {
    d <- draws[[c]]
    mean_val <- mean(d)
    med_val <- median(d)
    sd_val <- sd(d)
    q2.5 <- quantile(d, 0.025)
    q97.5 <- quantile(d, 0.975)
    pd_val <- max(mean(d > 0), mean(d < 0))
    
    # Statistical significance based on pd
    stars <- if (pd_val >= 0.999) {
      "***"
    } else if (pd_val >= 0.99) {
      "**"
    } else if (pd_val >= 0.975) {
      "*"
    } else {
      ""
    }
    
    formatted_mean <- sprintf("%.3f", mean_val)
    if (stars != "") {
      formatted_mean <- paste0("<b>", formatted_mean, stars, "</b>")
    }
    
    data.frame(
      Col = c,
      Mean = formatted_mean,
      Median = sprintf("%.3f", med_val),
      SD = sprintf("%.3f", sd_val),
      `CrI_2.5` = sprintf("%.3f", q2.5),
      `CrI_97.5` = sprintf("%.3f", q97.5),
      pd = sprintf("%.3f", pd_val),
      stringsAsFactors = FALSE
    )
  })
  
  df_sum <- bind_rows(summaries) %>%
    left_join(pred_map, by = c("Col" = "col")) %>%
    select(Predictor = clean_name, Mean, Median, SD, `CrI_2.5`, `CrI_97.5`, pd)
  return(df_sum)
}

sink("cache/table2_overclaim.md")
cat("**Table 2: Predictors of Overclaiming (Like Only)**\n\n")
print(kable(extract_eq(draws, "LikeOnly"), format = "pipe"))
sink()

sink("cache/table3_underclaim.md")
cat("**Table 3: Predictors of Underclaiming (Listen Only)**\n\n")
print(kable(extract_eq(draws, "ListenOnly"), format = "pipe"))
sink()

sink("cache/table4_consistent.md")
cat("**Table 4: Predictors of Consistent Engagement (Both)**\n\n")
print(kable(extract_eq(draws, "Both"), format = "pipe"))
sink()

# NOTE: Table 5 (Bayesian Mixed-Effects Model Fit Comparison) is NO LONGER
# generated here. The block that used to hand-type WAIC point estimates and
# marginal (not paired) standard errors was statistically invalid -- see
# Scripts/finish_loo_compare.R, which computes the correct PAIRED elpd_diff
# and se_diff via loo::loo_compare() across the final model set (Models 2,
# 4, and 5 use their Phase-1 convergence refits) and writes
# cache/table5_fit.md directly. Re-run that script (on Hoffman2) if any of
# the underlying model fits change; do not regenerate Table 5 here.
