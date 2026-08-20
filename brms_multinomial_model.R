# brms_multinomial_model.R
library(haven)
library(dplyr)
library(brms)

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

# Sample down for speed since we are testing this in a constrained environment
set.seed(42)
df_sample <- df_long %>% group_by(engagement_state) %>% sample_n(min(n(), 500)) %>% ungroup()

print("Fitting Bayesian Multinomial Mixed Model...")
# Family categorical defaults to multinomial logistic regression
# We use cmdstanr backend for faster compilation/sampling
fit_brm <- brm(
  formula = engagement_state ~ educ2 + child_arts + agecat + female + as.factor(race5) + 
    (1 | id) + (1 | genre_id),
  data = df_long,  # Use the FULL data now
  family = categorical(link = "logit"),
  chains = 4,
  cores = 4,
  iter = 2000,
  backend = "cmdstanr",
  init = 0,
  control = list(adapt_delta = 0.9)
)

summary(fit_brm)
saveRDS(fit_brm, "model_multinomial_brms.rds")
