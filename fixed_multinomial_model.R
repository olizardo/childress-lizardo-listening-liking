# fixed_multinomial_model.R
library(haven)
library(dplyr)
library(nnet)

df_long <- read_dta("analysis_time_long.dta")

# Create 4-level nominal outcome
df_long <- df_long %>%
  mutate(
    engagement_state = case_when(
      like == 0 & listen == 0 ~ "Neither",
      like == 0 & listen == 1 ~ "ListenOnly",
      like == 1 & listen == 0 ~ "LikeOnly",
      like == 1 & listen == 1 ~ "Both"
    ),
    engagement_state = factor(engagement_state, levels = c("Neither", "ListenOnly", "LikeOnly", "Both"))
  )

print("Fitting Fixed-Effects Multinomial Logistic Regression...")
model_fixed <- multinom(
  engagement_state ~ educ2 + child_arts + agecat + female + income + as.factor(race5),
  data = df_long
)

summary(model_fixed)

# Calculate p-values (nnet doesn't supply them by default)
z <- summary(model_fixed)$coefficients / summary(model_fixed)$standard.errors
p <- (1 - pnorm(abs(z), 0, 1)) * 2
print("P-Values for Fixed Effects:")
print(p)

saveRDS(model_fixed, "model_multinomial_fixed.rds")
