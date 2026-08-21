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
   - Instead of a simple binary, we modeled the data as four competing, mutually exclusive complex taste states:
     - `Neither` (Baseline: No like, no listen)
     - `ListenOnly` (Underclaim: Listen, but no like)
     - `LikeOnly` (Overclaim: Like, but no listen)
     - `Both` (True Engagement: Like AND listen)

3. **Modeling Strategy:**
   - *Fixed-Effects Multinomial Logistic Regression:* We successfully fit `nnet::multinom` models locally, incorporating fixed effects for all 20 genres as well as genre $\times$ arts exposure interactions (controlling for `platform`).
   - *Robust Inference:* We manually computed **Two-Way Cluster-Robust Standard Errors** (clustering simultaneously on `id` and `genre_id` using `sandwich::vcovCL`) to achieve valid inference accounting for repeated measures without crashing local memory. We manually extract diagonals to compute Z-scores/P-values and robust Wald tests (`aod::wald.test`) for joint significance.
   - *Hoffman2 `mblogit`:* For true multi-level inference, we bypassed local container memory limits by submitting penalized quasi-likelihood `mclogit::mblogit()` models with crossed random intercepts (`(1|id)` and `(1|genre_id)`) and random slopes (`child_arts|genre_id`) to the UCLA Hoffman2 HPC cluster. These models (which include the `platform` control) have successfully converged and been downloaded back to the local machine.

4. **Visualizations:**
   - **Descriptive Plots:** Generated clean lollipop (drop-line) charts mapping the baseline prevalence of Overclaiming, Underclaiming, and True Engagement for each specific genre.
   - **Marginal Effects & Interactions:** Used `marginaleffects` to calculate robust predicted probabilities and Average Marginal Effects (AMEs). Plotted these trajectories with clean vertical error bars, isolating the top and bottom of the education distribution (BA+ vs HS) and racial categories (Black vs White) to sharply capture demographic preference logic.
   - **Sociological Prestige Index:** Plotted the calculated AME of childhood arts on overclaiming against an aggregated "Prestige Index" (averaging the College/HS and Black/White preference ratios), revealing a massive positive Spearman correlation ($\rho \approx 0.64$) tying demographic exclusivity to the severity of symbolic overclaiming.

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
- The Hoffman2 HPC models (`model_mblogit.rds` and `model_mblogit_intercepts.rds`) have been downloaded successfully. Next step is to load these `.rds` files, extract the random effects (BLUPs), and compare them against the local fixed-effects interaction model.
