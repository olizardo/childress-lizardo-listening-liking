# multinomial_model.R
library(haven)
library(dplyr)
library(mclogit)

df_long <- read_dta("analysis_time_long.dta")

df_long <- df_long %>%
  mutate(
    engagement_state = case_when(
      like == 0 & listen == 0 ~ "1_Neither",
      like == 0 & listen == 1 ~ "2_ListenOnly",
      like == 1 & listen == 0 ~ "3_LikeOnly",
      like == 1 & listen == 1 ~ "4_Both"
    ),
    engagement_state = factor(engagement_state)
  )

# Ensure factors
df_long$id <- as.factor(df_long$id)
df_long$genre_id <- as.factor(df_long$genre_id)

print("Fitting Multinomial Mixed Model for competing engagement states...")
# Baseline is "1_Neither" (first alphabetically)

model_multi <- mblogit(
  engagement_state ~ educ2 + child_arts + agecat + female + income + as.factor(race5),
  random = list(~ 1|id, ~ 1|genre_id),
  data = df_long
)

summary(model_multi)
saveRDS(model_multi, "model_multinomial.rds")
