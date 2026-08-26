dir.create("cache", showWarnings = FALSE)

library(brms)
library(tidybayes)
library(dplyr)
library(knitr)
options(knitr.kable.NA = "—")

m_intercepts <- readRDS("rds/model_brms_intercepts.rds")
draws <- as_draws_df(m_intercepts)

# Wald Tests
compute_bayesian_wald <- function(draws) {
  b_cols <- grep("^b_", names(draws), value = TRUE)
  b_cols_no_int <- grep("Intercept", b_cols, value = TRUE, invert = TRUE)
  
  b_mat <- as.matrix(draws[, b_cols_no_int])
  mu_b <- colMeans(b_mat)
  sigma_b <- cov(b_mat)
  
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

wald_df <- compute_bayesian_wald(draws)
sink("cache/table1_wald.md")
cat("**Table 1: Joint Variable Importance (Bayesian Wald Chi-Square)**\n\n")
print(kable(wald_df, format = "pipe"))
sink()

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

# Fit Comparison (Streamlined ultra-concise column headers)
fit_table_bayes <- data.frame(
  Model = c(
    "1. Crossed Random Intercepts (Baseline)",
    "2. Constrained Slopes (Like Only)",
    "3. Constrained Slopes (Under- & Overclaiming)",
    "4. Constrained Slopes (Overclaiming & Consistent)",
    "5. Full Crossed Random Slopes (Preferred)"
  ),
  Under = c("—", "—", "✓", "—", "✓"),
  Over = c("—", "✓", "✓", "✓", "✓"),
  Both = c("—", "—", "—", "✓", "✓"),
  Par = c("4,820", "4,840", "4,860", "4,860", "4,880"),
  `WAIC (SE)` = c("48,917.4<br>(230.4)", "48,823.9<br>(229.6)", "48,822.1<br>(229.5)", "48,735.1<br>(229.5)", "48,732.4<br>(228.6)"),
  `Delta_WAIC` = c("0.0", "-93.5", "-95.3", "-182.3", "-185.0"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

sink("cache/table5_fit.md")
cat("**Table 5: Bayesian Mixed-Effects Model Fit Comparison**\n\n")
print(kable(fit_table_bayes, format = "pipe"))
sink()
