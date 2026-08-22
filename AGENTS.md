# Agent Handoff Document: Childress-Lizardo Listening vs Liking (Overclaiming)

## Project Goal
The core goal of this project is to study "overclaiming" in musical tastes: when individuals report that they like a musical genre in the abstract, but that genre is entirely absent when querying the artists and songs actually on their recent playlists.

## Current State & Key Milestones
1. **Data Wrangling:** 
   - Mapped 20 survey questions about abstract genre liking (`like_music_genres_X`) to the 20 consistent numeric genre codes used for classifying actual listened-to artists (`genre_final1` through `genre_final10`).
   - Created strict binary indicators: `like` (rated 5-7) and `listen` (genre appeared anywhere in top 10).
   - Reshaped the data into a long format (`analysis_time_long.dta`) containing 36,420 rows (20 genres × 1,821 respondents).
   - Created a custom `parent_educ` composite variable (`pmax(mom_educ, dad_educ)`).
   - Extracted and categorized the `stream_source` variable into a 4-level `platform` control (Free Recall, iTunes, Spotify, Winamp) to account for how respondents generated their top-10 lists.

2. **Complex Tastes Framework:**
   - Instead of a simple binary, we model the data as four competing, mutually exclusive complex taste states:
     - `Neither` (Baseline: No like, no listen)
     - `ListenOnly` (Underclaim: Listen, but no like)
     - `LikeOnly` (Overclaim: Like, but no listen)
     - `Both` (True Engagement: Like AND listen)

3. **Modeling Strategy:**
   - *Fixed-Effects Multinomial Logistic Regression:* We fit `nnet::multinom` models locally, incorporating fixed effects for all 20 genres as well as genre $\times$ arts exposure interactions (controlling for `platform`).
   - *Robust Inference:* We computed **Two-Way Cluster-Robust Standard Errors** (clustering simultaneously on `id` and `genre_id` using `sandwich::vcovCL`) to achieve valid inference accounting for repeated measures. We manually extract diagonals to compute Z-scores/P-values and robust Wald tests (`aod::wald.test`) for joint significance.
   - *Transition from PQL (`mblogit`) to Bayesian Estimation (`brms`):* Earlier penalized quasi-likelihood models (`mclogit::mblogit`) lacked credible uncertainty estimates for random coefficients and variance components. We transitioned the multilevel analysis entirely to full Bayesian MCMC estimation using `brms` and `cmdstanr`.
   - *Hoffman2 Bayesian HPC Jobs (Active):* Two Bayesian categorical mixed-effects models are currently running on Hoffman2 using 16 shared cores with within-chain multi-threading (4 chains × 4 threads):
     - **Model 1 (Crossed Random Intercepts, Job 14500225):** `(1 | id) + (1 | genre_id)` $\rightarrow$ `model_brms_intercepts.rds`
     - **Model 2 (Random Coefficients / Slopes, Job 14500226):** `(1 | id) + (1 + child_arts | genre_id)` $\rightarrow$ `model_brms_slopes.rds`

4. **Visualizations:**
   - **Descriptive Plots:** Generated clean lollipop (drop-line) charts mapping the baseline prevalence of Overclaiming, Underclaiming, and True Engagement for each specific genre.
   - **Marginal Effects & Interactions:** Used `marginaleffects` to calculate robust predicted probabilities and Average Marginal Effects (AMEs). Plotted these trajectories with vertical error bars, isolating the top and bottom of the education distribution (BA+ vs HS) and racial categories (Black vs White).
   - **Sociological Prestige Index:** Plotted the calculated AME of childhood arts on overclaiming against an aggregated "Prestige Index" (averaging the College/HS and Black/White preference ratios), revealing a strong positive Spearman correlation ($\rho \approx 0.64$) tying demographic exclusivity to the severity of symbolic overclaiming.

5. **Key Findings:**
   - **Childhood Arts Exposure** and **Parental Education** are the strongest and most robust global predictors of complex taste states. 
   - Arts exposure drastically increases True Engagement, but increases Overclaiming even faster.
   - **Crucial Interaction:** The effect of arts exposure on overclaiming is overwhelmingly concentrated on *culturally legitimated (highbrow)* genres like Classical, Opera, and Jazz. It has almost no effect on overclaiming Country, Rap, or Heavy Metal.

## Environment & Scripts
- All R scripts are organized in the `Scripts/` directory:
  - `Scripts/run_brms_intercepts.R` & `Scripts/submit_brms_intercepts.sh`: Bayesian crossed random-intercepts estimation on Hoffman2.
  - `Scripts/run_brms_slopes.R` & `Scripts/submit_brms_slopes.sh`: Bayesian random coefficient (arts slope) estimation on Hoffman2.
  - `Scripts/fixed_multinomial_model.R`: Local fixed-effects baseline multinomial models.
- All high-resolution plots are exported to the `Plots/` directory.
- Regression tables and model fit statistics are exported to `Tabs/` as HTML tables via `gt::gtsave()`.
- The primary reproducible document is `overclaiming_report.qmd` (rendered to `.html`).

## Next Steps
- Monitor completion of Hoffman2 jobs 14500225 and 14500226 (`qstat -u olizardo`).
- Download `model_brms_intercepts.rds` and `model_brms_slopes.rds` once sampling completes.
- Extract posterior distributions, credible intervals for variance parameters ($\Sigma$), and genre-specific random slope BLUPs/draws.
- Generate Bayesian AME plots with exact 95% posterior credible intervals and incorporate them into `overclaiming_report.qmd`.
