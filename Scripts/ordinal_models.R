# ordinal_models.R
# Script to fit ordinal models with IPW weights in the background

# Ensure VGAM is installed
if (!requireNamespace("VGAM", quietly = TRUE)) {
  install.packages("VGAM", repos = "http://cran.us.r-project.org")
}
library(VGAM)

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# Replace 'my_data.rds' with the actual path to your dataset
data_path <- "my_data.rds" 
output_path <- "model_results.rds"

# Try loading the data (placeholder logic for now)
if (file.exists(data_path)) {
  df <- readRDS(data_path)
} else {
  # Create dummy data so the script doesn't fail if run for testing
  set.seed(123)
  df <- data.frame(
    eval.g = factor(sample(1:4, 1000, replace = TRUE), ordered = TRUE),
    education = rnorm(1000),
    ipw_weights = runif(1000, 0.5, 1.5),
    year = sample(2020:2023, 1000, replace = TRUE),
    captcha_score = runif(1000, 0, 1),
    order = sample(1:2, 1000, replace = TRUE)
  )
}

# Ensure eval.g is an ordered factor
df$eval.g <- as.ordered(df$eval.g)

# Define the model formula
# (Excluding experimental conditions, including education and survey controls)
formula_base <- eval.g ~ education + year + captcha_score + order

print("Fitting Cumulative Link Logit Model...")
# 1. Cumulative Link Logit Model (Proportional Odds)
# family = cumulative(parallel = TRUE) enforces the proportional odds constraint
fit_clm <- vglm(
  formula = formula_base,
  family = cumulative(parallel = TRUE),
  data = df,
  weights = ipw_weights
)

print("Fitting Adjacent Category Model (Proportional Constraints)...")
# 2. Adjacent Category Model (With proportional constraints)
# parallel = TRUE enforces proportional constraints across categories
fit_acat_prop <- vglm(
  formula = formula_base,
  family = acat(parallel = TRUE),
  data = df,
  weights = ipw_weights
)

print("Fitting Adjacent Category Model (No Proportional Constraints)...")
# 3. Adjacent Category Model (Without proportional constraints)
# parallel = FALSE allows the effects to vary across category transitions
fit_acat_nonprop <- vglm(
  formula = formula_base,
  family = acat(parallel = FALSE),
  data = df,
  weights = ipw_weights
)

# ==============================================================================
# SAVE RESULTS
# ==============================================================================
# Save the fitted model objects to an RDS file so they can be inspected later
results_list <- list(
  clm_model = fit_clm,
  acat_prop_model = fit_acat_prop,
  acat_nonprop_model = fit_acat_nonprop
)

saveRDS(results_list, output_path)
print(paste("Models successfully fitted and saved to", output_path))
