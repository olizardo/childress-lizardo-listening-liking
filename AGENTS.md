# Agent Handoff Document: Childress-Lizardo Listening vs Liking (Overclaiming)

## Project Goal
The core goal of this project is to study "overclaiming" in musical tastes: when individuals report that they like a musical genre in the abstract, but that genre is entirely absent when querying the artists and songs actually on their recent playlists.

## Current State & Key Milestones
1. **Data Wrangling:** 
   - Mapped 20 survey questions about abstract genre liking (`like_music_genres_X`) to the 20 consistent numeric genre codes used for classifying actual listened-to artists (`genre_final1` through `genre_final10`).
   - Created strict binary indicators: `like` (rated 5-7) and `listen` (genre appeared anywhere in top 10).
   - Reshaped the data into a long format (`analysis_time_long.dta`) containing 36,420 rows (20 genres × 1,821 respondents).
   - Created a custom `parent_educ` composite variable (`pmax(mom_educ, dad_educ)`).

2. **Complex Tastes Framework:**
   - Instead of a simple binary, we modeled the data as four competing, mutually exclusive complex taste states:
     - `Neither` (Baseline: No like, no listen)
     - `ListenOnly` (Underclaim: Listen, but no like)
     - `LikeOnly` (Overclaim: Like, but no listen)
     - `Both` (True Engagement: Like AND listen)

3. **Modeling Strategy:**
   - *Fixed-Effects Multinomial Logistic Regression:* We successfully fit `nnet::multinom` models locally, incorporating fixed effects for all 20 genres as well as genre $\times$ arts exposure interactions.
   - *Robust Inference:* We manually computed **Two-Way Cluster-Robust Standard Errors** (clustering simultaneously on `id` and `genre_id` using `sandwich::vcovCL`) to achieve valid inference accounting for repeated measures without crashing local memory. We manually extract diagonals to compute Z-scores/P-values and robust Wald tests (`aod::wald.test`) for joint significance.
   - *Hoffman2 `mblogit`:* For true multi-level inference, we bypass the local container memory limits by submitting a penalized quasi-likelihood `mclogit::mblogit()` model with crossed random intercepts (`(1|id)` and `(1|genre_id)`) and random slopes (`child_arts|genre_id`) to the UCLA Hoffman2 HPC cluster. (Note: `mblogit` requires crossed effects to be passed as a `list()`).

4. **Visualizations:**
   - **Descriptive Plots:** Generated clean lollipop (drop-line) charts mapping the baseline prevalence of Overclaiming, Underclaiming, and True Engagement for each specific genre.
   - **Marginal Effects & Interactions:** Used `marginaleffects` to calculate robust predicted probabilities and Average Marginal Effects (AMEs). Plotted these trajectories with clean vertical error bars. Plotted the 20-way genre interaction to show the massive heterogeneity in how arts exposure affects different genres.

5. **Key Findings:**
   - **Childhood Arts Exposure** and **Parental Education** are the strongest and most robust global predictors of complex taste states. 
   - Arts exposure drastically increases True Engagement, but increases Overclaiming even faster.
   - **Crucial Interaction:** The effect of arts exposure on overclaiming is overwhelmingly concentrated on *culturally legitimated (highbrow)* genres like Classical, Opera, and Jazz. It has almost no effect on overclaiming Country, Rap, or Heavy Metal.

## Environment & Scripts
- All R scripts are organized in the `Scripts/` directory.
- All high-resolution plots are exported to the `Plots/` directory.
- Regression tables and model fit statistics are explicitly exported to the `Tabs/` directory as HTML tables via `gt::gtsave()`.
- The final, end-to-end reproducible document is `overclaiming_report.qmd` (rendered to `.html`).

## Next Steps
- The data and fixed-effects analysis pipeline are completely clean and stable.
- Once the Hoffman2 HPC models (`model_mblogit.rds` and `model_mblogit_intercepts.rds`) finish running, download them and extract the random effects (BLUPs) to compare against the local fixed-effects interaction model.
