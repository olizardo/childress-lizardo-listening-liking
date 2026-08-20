# Agent Handoff Document: Childress-Lizardo Listening vs Liking (Overclaiming)

## Project Goal
The core goal of this project is to study "overclaiming" in musical tastes: when individuals report that they like a musical genre in the abstract, but that genre is entirely absent when querying the artists and songs actually on their recent playlists.

## Current State & Key Milestones
1. **Data Wrangling:** 
   - Mapped 20 survey questions about abstract genre liking (`like_music_genres_X`) to the 20 consistent numeric genre codes used for classifying actual listened-to artists (`genre_final1` through `genre_final10`).
   - Created strict binary indicators: `like` (rated 5-7) and `listen` (genre appeared anywhere in top 10).
   - Reshaped the data into a long format (`analysis_time_long.dta`) containing 36,420 rows (20 genres × 1,821 respondents).
   - Created a custom `parent_educ` composite variable (`pmax(mom_educ, dad_educ)`).

2. **Competing States Framework:**
   - Instead of a simple binary, we modeled the data as four competing, mutually exclusive engagement states:
     - `Neither` (Baseline: No like, no listen)
     - `ListenOnly` (Underclaim: Listen, but no like)
     - `LikeOnly` (Overclaim: Like, but no listen)
     - `Both` (True Engagement: Like AND listen)

3. **Modeling Strategy (The Two-Way Clustering Solution):**
   - *Initial Attempts:* We tried fitting Bayesian multinomial mixed-effects models (`mblogit`, `brms`/`cmdstanr`) with crossed random intercepts `(1|id) + (1|genre_id)`. These failed due to massive matrix allocation limits (memory exhaustion) for the C++ samplers inside the local container.
   - *Final Solution:* We successfully fit a **Fixed-Effects Multinomial Logistic Regression** (`nnet::multinom`). To achieve valid inference accounting for the repeated measures, we manually computed **Two-Way Cluster-Robust Standard Errors** (clustering simultaneously on `id` and `genre_id` using `sandwich::vcovCL`). 
   - *Note on `gt` and `coeftest`:* Because `nnet` flattens standard errors across categories, `coeftest` fails to format them. We manually extract the variance diagonals, compute Z-scores/P-values, and pipe them into publication-ready `gt` tables.

4. **Visualizations:**
   - **Descriptive Plots:** Generated clean lollipop (drop-line) charts mapping the baseline prevalence of Overclaiming, Underclaiming, and True Engagement for each specific genre, ordered by prevalence, with dashed lines indicating the cross-genre mean.
   - **Marginal Effects:** Used `marginaleffects` to calculate robust predicted probabilities across levels of `child_arts` (Childhood Arts Exposure) and `educ2` (Education). Plotted these trajectories with clean vertical error bars representing the 95% two-way clustered confidence intervals.

5. **Key Findings:**
   - **Childhood Arts Exposure** is the strongest and most robust predictor of Overclaiming. It drastically increases True Engagement, but increases Overclaiming even faster.
   - **Education** acts similarly, but is also uniquely significant in predicting Underclaiming (Listen Only).
   - **Race** effects (e.g., Black respondents overclaiming more) washed out completely once we clustered standard errors at the genre level, indicating the effect was entirely driven by baseline differences in *which* genres were preferred, rather than a demographic propensity to overclaim.

## Environment & Scripts
- All R scripts are organized in the `Scripts/` directory.
- All high-resolution plots are exported to the `Plots/` directory.
- The `renv` environment is strictly managed. Packages rely heavily on Linux binaries via Posit Public Package Manager to avoid source compilation timeouts.
- The final, end-to-end reproducible document is `overclaiming_report.qmd` (rendered to `.html`).

## Next Steps
- The data and analysis pipeline are completely clean and stable. Future work could involve exporting the `gt` tables to LaTeX/Word for a manuscript or running robustness checks on the Likert threshold (e.g., scoring only 6-7 as `like`).
