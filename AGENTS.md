# Agent Handoff Document: Childress-Lizardo Listening vs Liking (Overclaiming)

## Project Goal
The core goal of this project is to study "overclaiming" in musical tastes: when individuals report that they like a musical genre in the abstract, but that genre is entirely absent when querying the artists and songs actually on their recent playlists.

---

## Current State & Key Milestones

### 1. Data Wrangling, Survey Items & Demographic Predictors
- **Survey Items & Wording:**
  - *Abstract Genre Liking:* *"How much do you like listening to the following genres of music?"* (7-point Likert scale from 1 = "Very Much Dislike" to 7 = "Very Much Like" across 20 standardized genres).
  - *Concrete Listening Behavior:* Screened for primary player (`how_listen`) with *"Do you currently have access to your iTunes?"* (or Spotify / Winamp). Respondents with library access sorted tracks by **"Plays"** (play counts) to enter top ten artists, play counts, and genres (`itunes_1_1`–`_10_3`, `spotify_comp1_1_1`–`_10_1`, `winamp_monkey_1_1`–`_10_3`). Respondents without play-count tracking reported the top ten artists in **regular rotation** (`rotation1_1_1`–`_rotation2_10`).
  - *Childhood Arts Exposure (`child_arts`):* *"During your childhood how frequently did your parents or guardians engage you with the arts?"* (1 = "Not At All" to 7 = "All The Time").
  - *Educational Attainment (`educ` / `educ2`):* Six collapsed tiers (Less than High School, High School Graduate, Some College, Associate's Degree, Bachelor's Degree, Graduate Degree).
  - *Parental Education (`parent_educ`):* Household maximum of maternal (`mom_educ`) and paternal (`dad_educ`) educational attainment.
  - *Age Categories (`agecat`):* Six cohorts based on birth year: Under 30 (1989–2000), 30–39 (1979–1988), 40–49 (1969–1978), 50–59 (1959–1968), 60–69 (1949–1958), 70 and Older (1928–1948).
  - *Household Income (`income`):* Twelve brackets from Less than $10,000 up to $150,000 or More.
  - *Gender Identification (`female`):* Binary indicator for women ($N = 917$ women, $N = 902$ men).
  - *Ethnoracial Identification (`race5`):* Five standardized categories: White (baseline), Black, Hispanic, Asian, and Other/Mixed.
  - *Streaming Platform (`platform`):* Four operational modes: Free Recall ($N = 1,200$), iTunes ($N = 341$), Spotify ($N = 270$), and Winamp ($N = 10$).
- **Long-Format Data:** Reshaped master survey data into `dta/analysis_time_long.dta` (24,457 valid person-genre observations across 1,574 respondents).

### 2. Complex Tastes Framework
Instead of a simple binary, we model the data as four competing, mutually exclusive nominal complex tastes:
- `Neither` (Baseline: No like, no listen)
- `ListenOnly` (Underclaim: Listen, but no like — "guilty pleasure" / ambient listening)
- `LikeOnly` (Overclaim: Like, but no listen — symbolic boundary claiming)
- `Both` (Consistent Engagement: Like AND listen — congruent active consumption)

### 3. Comprehensive Modeling Strategy: Pure Bayesian Hierarchical Framework
All legacy frequentist ML (`nnet::multinom`) models have been completely replaced by **Bayesian Crossed Random-Effects Multinomial Logistic Regressions** (`brms` + `cmdstanr`), providing exact posterior inference that fully respects person-level clustering, genre-level variation, and regularized shrinkage:
1. **Model 1 (Crossed Random Intercepts):** `(1 | id) + (1 | genre_id)` across all logits $\rightarrow$ `rds/model_brms_intercepts.rds` (WAIC = 48,917.4). Baseline model for the joint importance tests (Table 1), fixed-effect parameter tables (Tables 2–4), predicted probability plots, and the genre-level "purged engagement profile" figure (Figure 1) since it has no genre-level slopes.
2. **Model 2 (Constrained Slopes — Like Only):** Random slopes `(1 + child_arts | genre_id)` strictly on `muLikeOnly` $\rightarrow$ **refit** `rds/model_brms_constrained_likeonly_refit.rds` (original fit failed convergence check, see §3a).
3. **Model 3 (Constrained Slopes — Under- & Overclaim):** Random slopes `(1 + child_arts | genre_id)` on `muListenOnly` and `muLikeOnly` $\rightarrow$ `rds/model_brms_constrained_under_over.rds` (original fit passed convergence, no refit needed).
4. **Model 4 (Constrained Slopes — Overclaiming & Consistent, PREFERRED):** Random slopes `(1 + child_arts | genre_id)` on `muLikeOnly` and `muBoth` only $\rightarrow$ **refit** `rds/model_brms_constrained_over_true_refit.rds`. This is now the preferred specification for all genre-level analyses (see §4).
5. **Model 5 (Full Crossed Random Slopes):** `(1 | id) + (1 + child_arts | genre_id)` across all logits $\rightarrow$ **refit** `rds/model_brms_slopes_refit.rds`. Statistically indistinguishable from Model 4 (see §4) — no longer treated as the preferred model.

**3a. Convergence refits (2026-09-28 session).** `Scripts/check_convergence.R` found Models 2, 4, and 5 exceeded $\hat{R} < 1.01$ (max $\hat{R}$ up to 1.028 in Model 4), though none had divergences or treedepth issues. All three were refit with `iter = 4000, warmup = 1500, adapt_delta = 0.97` (`Scripts/run_brms_*_refit.R`, submitted via the matching `submit_brms_*_refit.sh`), after which all 5 specifications pass standard diagnostics (max $\hat{R} = 1.008$, min bulk ESS $= 482$, zero divergences — see `cache/table_diagnostics_final.md`). **Always use the `_refit` versions of Models 2, 4, and 5** for any new analysis; the original (non-refit) `.rds` files are kept only for provenance.

### 4. Corrected Bayesian Model Selection (paired `loo_compare`, not raw ΔWAIC)

The original 5-model comparison table compared models using *independently computed* WAIC standard errors (~229 for every model), which made every ΔWAIC look large relative to noise. This was **statistically invalid** — the correct comparison uses `loo::loo_compare()`'s *paired* pointwise `elpd_diff`/`se_diff`, computed in `Scripts/finish_loo_compare.R`:

| Model Specification | WAIC (SE) | elpd_diff | se_diff | ratio |
| :--- | :---: | :---: | :---: | :---: |
| 1. Crossed Random Intercepts | 48,917.4 (228.9) | -93.2 | 13.5 | -6.90 |
| 2. Constrained Slopes (Like Only) [REFIT] | 48,828.1 (229.5) | -48.6 | 9.5 | -5.13 |
| 3. Constrained Slopes (Under- & Overclaiming) | 48,822.1 (229.5) | -45.6 | 9.1 | -5.00 |
| **4. Constrained Slopes (Overclaiming & Consistent) [REFIT] — PREFERRED** | **48,730.9 (229.5)** | **0.0** | — | — |
| 5. Full Crossed Random Slopes [REFIT] | 48,731.4 (229.5) | -0.2 | 1.3 | -0.20 |

- **Models 1–3 are decisively worse** than 4/5 (paired ratios −5.0 to −6.9): allowing genre-varying returns to childhood arts exposure materially improves fit, but only once both `LikeOnly` *and* `Both` get genre-specific slopes (Model 3, which only adds a `ListenOnly` slope on top of Model 2, barely moves the needle).
- **Models 4 and 5 are statistically indistinguishable** (elpd_diff = −0.2, se_diff = 1.3, ratio = −0.20 — a fifth of one standard error). Model 4 achieves this with 20 fewer parameters (no genre-specific `ListenOnly` slope), so **parsimony now favors Model 4**, reversing the project's earlier working conclusion that Model 5 was preferred. All genre-level figures/analyses should be regenerated from Model 4 going forward.
- **Caveat:** Models 1–3 show 2.8–3.0% of observations with $p_{\text{waic}} > 0.4$, the standard flag that WAIC may be unstable for those pointwise contributions (PSIS-LOO preferred in principle, but full LOO with many cores previously caused socket timeouts on this cluster — see HPC section below). Unlikely to change the ranking given the size of the gaps, but the Models 1–3 WAIC values should be read as approximate.

### 5. Key Empirical Findings (updated to Model 4, the preferred specification)
- **Highbrow Concentration:** Immersion in childhood arts increases the odds of overclaiming Opera by **15.2-fold** (95% CrI: [8.38, 28.04]) and Classical music by **12.2-fold** (95% CrI: [7.31, 20.57]). Country is the only genre whose 95% credible interval crosses unity ($\text{OR} = 1.03$, 95% CrI: [0.60, 1.76]). These are nearly identical to the old Model-5-based estimates, as expected given Models 4/5 are statistically tied.
- **Educational Prestige Governs Overclaiming:** Bayesian overclaiming odds ratios correlate strongly with Class Prestige (the College/HS liking ratio; posterior-median point estimate $r = 0.78$, Spearman $\rho = 0.70$; full posterior draw-wise median $r = 0.74$, 95% CrI [0.60, 0.83], median $\rho = 0.66$, 95% CrI [0.52, 0.77]). The racial preference ratio (Black-to-White liking) correlation is markedly weaker but not negligible (draw-wise median $\rho = 0.44$, 95% CrI [0.28, 0.58]).
- **Negative Intercept-Slope Correlation:** Genre random intercepts ($u_0$) and arts random slopes ($u_1$) for overclaiming correlate at $r = -0.83$ ($\rho = -0.82$, from Model 4). **Sensitivity caveat:** with only $J=20$ genre clusters, this correlation is sensitive to the LKJ prior's concentration — it ranges from $-0.65$ (LKJ(4)) to $-0.77$ (LKJ(1)) across three prior settings tested in `Scripts/sensitivity_lkj_prior.R` (all exclude zero, so the *direction* is robust, but not the exact magnitude).
- **Corrected Genre Profiles (from Model 1, the true no-slopes baseline — see note below):** Within-genre centered random intercepts ($\Delta u_{0jk} = u_{0jk} - \bar{u}_{0j}$) cancel the baseline popularity artifact, revealing qualitative clusters at the directional credibility rule ($\text{pd} \ge 0.95$):
  - *Overclaiming Tilt:* Bluegrass, Classical, Jazz, Musicals, Oldies, Opera, Swing/Big Band.
  - *Consistent Tilt:* Classic Rock, Contemporary Pop, Contemporary Rock, Country, Oldies, Rap/Hip Hop.
  - *Underclaiming Tilt:* Only Rap/Hip Hop reaches $\text{pd} \ge 0.95$ (Heavy Metal falls just short at $\text{pd} = 0.949$) — a much narrower signal than earlier reported.
  - **Bug fixed (2026-09-28):** `Scripts/plot_purged_random_intercepts.R` (Figure 1) and `Scripts/plot_random_intercepts_halfeye.R` had been silently loading the random-**slopes** model even though the manuscript's own text/equation describe this figure as coming from the pure-intercepts baseline (Model 1). Fixed to load Model 1 directly; the genre classification above reflects the corrected, model-1-based estimates and differs from what was previously reported (which had actually come from the slopes model despite the text's claim otherwise).
- **Predicted Probability Shift (Baseline Model):** Moving from childhood arts exposure level 1 to 7 increases the predicted probability of Overclaiming from **19.4%** to **45.7%** (+26.3 pp), while Consistent Engagement rises modestly from **9.0%** to **12.5%** (+3.5 pp), Underclaiming declines from **11.1%** to **6.0%**, and non-engagement (*Neither*) drops from **59.5%** to **34.9%**. (Unaffected by the Model 4/5 correction — sourced from Model 1.)
- **Robustness checks (all stable, see `cache/robustness_platform.csv`, `cache/prior_sensitivity_model1.csv`):** the `child_arts` coefficients are essentially unchanged whether the small Winamp platform cell ($N=10$) is included, dropped, or collapsed into "Other," and whether the fixed-effect prior is $\mathcal{N}(0,1.5)$ or a wider $\mathcal{N}(0,3)$.
- **Statistical hygiene notes:** the "Bayesian Wald test" (Table 1) is an *asymptotic* posterior Wald-type statistic (posterior mean/covariance treated as an asymptotically normal sampling distribution, referred to a $\chi^2$ reference distribution) — not a classical frequentist test. A posterior-normality check (`cache/table1b_wald_normality_check.md`) confirms all 39 constituent coefficients fall within conventional skewness/kurtosis bounds, supporting but not proving the approximation. A posterior predictive check on Model 1 (`cache/posterior_predictive_check.csv`, `Plots/PPC_Genre_State_Proportions.png`) found 0 of 80 genre-by-state observed proportions falling outside the model's 95% posterior predictive interval.
- **Reproducibility & Environment:** Full bibliography integration via `references.bib` citing R v4.5.3, `brms` v2.23.0, and `CmdStan` v2.33.1 / `cmdstanr` (note: model-fitting scripts pin CmdStan 2.33.1 via `cmdstanr::set_cmdstan_path`, distinct from the locally-installed 2.39.0 used for lightweight post-processing), with `renv` environment locked. **Known gap:** `mvtnorm` was missing from the local `renv` library as of 2026-09-28 (fixed via `Rscript -e 'install.packages("mvtnorm")'`, not `renv::install()`, which hung — see HPC/local-execution notes below).

### 6. Google Drive Manuscript Synchronization — Google Doc is now the SOLE manuscript (no local .qmd)
- **Live Manuscript Document:** *Liking/Listening Omnivore Data*
- **Google Doc URL:** `https://docs.google.com/document/d/1vXW0PsCeXUghrCbfIylU-RjzpjQOK1uqrZ03NNMnb7k/edit?usp=sharing`
- **Google Doc ID:** `1vXW0PsCeXUghrCbfIylU-RjzpjQOK1uqrZ03NNMnb7k`
- **IMPORTANT (2026-09-28): `overclaiming_report.qmd` and `overclaiming_report.html` have been deleted from this repository at the user's request.** The Google Doc is now the only manuscript; there is no local Quarto source to render or keep in sync with. Any future prose edits (new sections, rewritten paragraphs, a new Limitations section, etc.) must be authored directly against the live Google Doc — either by hand, or via a bespoke OpenXML paragraph-injection script modeled on `Scripts/inject_limitations_section.py` (which inserts a new Heading1 section immediately before an existing Heading1 anchor, idempotently, and validates well-formedness before writing). The existing `Scripts/sync_manuscript.R` / `sync_manuscript.py` pipeline only handles **tables and figures** (via caption-text matching against `cache/*.md` and `Plots/*.png`), not arbitrary prose — it does not need or reference the deleted `.qmd` file.
- **Manuscript Update Command (CRITICAL FOR FUTURE AGENTS) — tables & figures only:**
  ```bash
  Rscript Scripts/sync_manuscript.R
  ```
  This downloads the live manuscript, performs in-place DOM-based replacement of all tables (APA 7th standard format) and figures (exact 6.5-inch extent synchronization) by matching existing captions, and uploads the updated document back to Google Drive without disrupting text typography, comments, or heading structure. **Caveat learned 2026-09-28:** if a table's caption text changes (e.g., relabeling "Bayesian Wald Chi-Square" to "Asymptotic Posterior Wald-Type Statistic"), the caption-match will fail and the script falls back to *appending* a new table at the end rather than replacing in place. Verify after running whether this happened (inspect `word/document.xml` inside the downloaded `.docx` for duplicate `<w:tbl>` elements with the same logical content) — in practice this has NOT actually produced duplicates so far (the doc previously had only bracket placeholder text like `[Table 1 about here]`, not real tables, so "append" was really "first insertion"), but always verify with a fresh download + inspection rather than trusting the script's console log alone.
- **New prose-injection capability:** `Scripts/inject_limitations_section.py <in_docx> <out_docx>` — a template for inserting a brand-new Heading1 section (title + bold-lead body paragraphs) into the live document immediately before another named Heading1 section. Idempotent (checks for the target heading before inserting). Used to add the manuscript's new **Limitations** section (genre-level random-slope identifiability / LKJ sensitivity, small-cell Winamp platform robustness, single-item `child_arts` measurement, WAIC approximation quality, asymptotic Wald-test approximation) directly before "References" in the live Doc on 2026-09-28.
- **Synchronized Table/Figure Assets Mapping:**
  - `Table 1` $\leftarrow$ Asymptotic posterior Wald-type statistics (`cache/table1_wald.md`), with companion normality diagnostic `cache/table1b_wald_normality_check.md`.
  - `Table 2/3/4` $\leftarrow$ Posterior parameters for Overclaiming / Underclaiming / Consistent Engagement, from Model 1 (`cache/table2_overclaim.md`, `table3_underclaim.md`, `table4_consistent.md`).
  - `Table 5` $\leftarrow$ Corrected paired-`loo_compare` 5-model fit comparison (`cache/table5_fit.md`, generated by `Scripts/finish_loo_compare.R` — **not** `generate_md_tables.R`, which no longer generates Table 5 at all after the invalid-SE bug was found; see script header comment).
  - `Figure 1.` $\leftarrow$ Purged genre engagement profiles, **from Model 1** (`Plots/Purged_Genre_Engagement_Profiles.png`).
  - `Figure 2.` $\leftarrow$ Predicted probabilities across arts exposure, from Model 1 (`Plots/ChildArts_Effects_Bayesian_CrI.png` — note: no generating script currently exists in `Scripts/`; this figure was produced ad hoc in a prior session and is a reproducibility gap that should eventually be scripted).
  - `Figure 3.` $\leftarrow$ Liking vs. listening omnivorousness capacity (`Plots/ChildArts_Omnivorousness_Capacity.png`).
  - `Figure 4.` $\leftarrow$ Genre-specific arts exposure odds ratios half-eye plot, **from Model 4 (refit)** (`Plots/ChildArts_Odds_Overclaiming_HalfEye.png`), with per-genre CrIs cached to `cache/odds_overclaiming_by_genre.csv`.
  - `Figure 5.` $\leftarrow$ Baseline intercept vs. arts slope correlation, **from Model 4 (refit)** (`Plots/Overclaim_Random_Intercept_Slope_Correlation.png`), point estimates cached to `cache/correlation_point_estimates.csv` and `cache/genre_summary_correlations.csv`.
  - `Figure 6.` $\leftarrow$ Educational prestige vs. Bayesian odds ratio correlation, **from Model 4 (refit)** (`Plots/Bayesian_Odds_Prestige_Correlation.png`), with the full posterior draw-wise correlation distribution cached to `cache/correlation_draws_summary.csv`.

---

## Directory & File Structure

**Note: there is no local manuscript source file.** `overclaiming_report.qmd` / `.html` were deleted on 2026-09-28; the manuscript lives solely in the Google Doc (§6 above). `Scripts/` and `cache/` still exist purely to feed tables/figures into that Doc.

```
.
├── Scripts/
│   ├── sync_manuscript.R                   # Turnkey Google Drive sync wrapper (tables + figures only)
│   ├── sync_manuscript.py                  # OpenXML DOM-based table and figure injector
│   ├── inject_limitations_section.py       # OpenXML prose-section injector (Heading1 + body paragraphs, idempotent)
│   ├── generate_md_tables.R                # Pre-computes Tables 1/1b/2/3/4 to cache/ (NOT Table 5 anymore -- see finish_loo_compare.R)
│   ├── run_brms_intercepts.R               # Model 1: Bayesian random intercepts
│   ├── submit_brms_intercepts.sh           # SGE 16-core submit wrapper
│   ├── run_brms_slopes.R / run_brms_slopes_refit.R           # Model 5 original / convergence refit
│   ├── submit_brms_slopes.sh / submit_brms_slopes_refit.sh
│   ├── run_brms_constrained.R / run_brms_constrained_refit.R # Model 2 original / convergence refit
│   ├── submit_brms_constrained.sh / submit_brms_constrained_refit.sh
│   ├── run_brms_constrained_under_over.R   # Model 3 (no refit needed)
│   ├── submit_brms_constrained_under_over.sh
│   ├── run_brms_constrained_over_true.R / run_brms_constrained_over_true_refit.R # Model 4 (PREFERRED) original / refit
│   ├── submit_brms_constrained_over_true.sh / submit_brms_constrained_over_true_refit.sh
│   ├── check_convergence.R / check_convergence_refits.R      # Rhat/ESS/divergence diagnostics (orig 5 models / 3 refits)
│   ├── compute_loo_compare.R / finish_loo_compare.R          # Paired loo_compare Table 5 builder (finish_* is the one actually used; loads models one-at-a-time to bound memory)
│   ├── sensitivity_lkj_prior.R / finish_sensitivity_lkj.R    # LKJ(1)/(2)/(4) prior sensitivity refits + comparison extraction
│   ├── robustness_platform.R / finish_robustness_platform.R # Winamp-cell (N=10) robustness refits + comparison extraction
│   ├── prior_sensitivity_model1.R / finish_prior_sensitivity_model1.R # Fixed-effect prior width sensitivity (Model 1)
│   ├── posterior_predictive_check.R        # Model 1 PPC: observed vs. predicted genre x state proportions
│   ├── extract_waic_only.R                 # Standalone one-shot WAIC extraction subprocess (memory-safe pattern)
│   ├── plot_purged_random_intercepts.R     # Figure 1: composite 3-panel within-genre centered profiles, FROM MODEL 1 (pd >= 0.95)
│   ├── plot_random_intercepts_halfeye.R    # Supplementary per-state random-intercept half-eyes, FROM MODEL 1
│   ├── plot_correlations.R                 # Figures 5/6: prestige & intercept-slope correlations, FROM MODEL 4 (refit); also computes posterior draw-wise correlation stats
│   ├── plot_odds_overclaiming_halfeye.R    # Figure 4: tidybayes half-eye plot of arts exposure odds ratios, FROM MODEL 4 (refit)
│   ├── plot_omnivorousness_capacity.R      # Figure 3: stated liking vs concrete listening capacity divergence
│   ├── fixed_multinomial_model.R           # Local multinom baseline
│   ├── clean_artistgenre.R                 # Artist-to-genre classification
│   └── analysis_time.R                     # Long-format data preparation
├── cache/
│   ├── table1_wald.md / table1b_wald_normality_check.md   # Table 1 + normality diagnostic
│   ├── table2_overclaim.md / table3_underclaim.md / table4_consistent.md
│   ├── table5_fit.md / table5_fit_raw.csv                 # Corrected paired loo_compare table (from finish_loo_compare.R)
│   ├── table_diagnostics.md / table_diagnostics_refits.md / table_diagnostics_final.md  # Convergence diagnostics (orig / refits / combined)
│   ├── diagnostics_summary.csv / diagnostics_summary_refits.csv
│   ├── sensitivity_lkj.csv / robustness_platform.csv / prior_sensitivity_model1.csv      # Sensitivity/robustness check results
│   ├── odds_overclaiming_by_genre.csv / genre_summary_correlations.csv / correlation_point_estimates.csv / correlation_draws_summary.csv
│   ├── purged_genre_profiles_credsummary.csv               # Model-1-based genre credibility classifications (Figure 1)
│   └── posterior_predictive_check.csv                      # Model 1 PPC results
├── docs/
│   ├── qualtrics-data-codebook.qmd         # Qualtrics codebook with question texts & blocks
│   ├── qualtrics-data-codebook.html        # Rendered Qualtrics codebook
│   ├── codebook.qmd                        # General project codebook
│   ├── codebook.html                       # Rendered general codebook
│   ├── variables_metadata.txt              # Variable descriptions & metadata
│   └── survey_instruments/
│       ├── Final_Survey.pdf                # Raw survey questionnaire PDF
│       └── Final_Survey_Text.txt           # Text extraction of survey instrument
├── dta/
│   ├── analysis_time_CCC.dta               # Master survey dataset
│   ├── analysis_time_long.dta              # Long-format person-genre dataset
│   ├── analysis_time_R_processed.dta       # Wide processed dataset
│   └── genresobjects.dta                   # Genre object crosswalk
├── rds/
│   ├── model_brms_intercepts.rds                        # Model 1 (121 MB) -- used as-is, passed convergence
│   ├── model_brms_slopes.rds / model_brms_slopes_refit.rds                 # Model 5 original / REFIT (use refit)
│   ├── model_brms_constrained_likeonly.rds / *_refit.rds                   # Model 2 original / REFIT (use refit)
│   ├── model_brms_constrained_under_over.rds                               # Model 3 -- used as-is, passed convergence
│   ├── model_brms_constrained_over_true.rds / *_refit.rds                  # Model 4 (PREFERRED) original / REFIT (use refit)
│   ├── model_brms_slopes_lkj1.rds / model_brms_slopes_lkj4.rds             # LKJ prior sensitivity refits (Model 5 structure)
│   ├── model_robustness_no_winamp.rds / model_robustness_winamp_collapsed.rds  # Platform robustness refits (Model 1 structure)
│   ├── model_brms_intercepts_wideprior.rds                                 # Prior-width sensitivity refit (Model 1, normal(0,3))
│   ├── waic_brms_*.rds                                                     # Small (~550KB) cached WAIC objects per model -- load these, not full fits, when only WAIC is needed
│   ├── robust_vcov_twoway.rds              # Two-way cluster-robust covariance matrix
│   ├── ame_genre_fixed.rds                 # AME calculations across all states
│   └── ame_genre_constrained.rds           # Constrained LikeOnly AME dataframe (educational/racial preference ratios)
├── Plots/
│   ├── Bayesian_Odds_Prestige_Correlation.png          # Figure 6, FROM MODEL 4 (refit)
│   ├── ChildArts_Effects_Bayesian_CrI.png              # Figure 2, from Model 1 (no generating script -- reproducibility gap)
│   ├── ChildArts_Odds_Overclaiming_HalfEye.png         # Figure 4, FROM MODEL 4 (refit)
│   ├── ChildArts_Omnivorousness_Capacity.png           # Figure 3
│   ├── Overclaim_Random_Intercept_Slope_Correlation.png # Figure 5, FROM MODEL 4 (refit)
│   ├── Purged_Genre_Engagement_Profiles.png            # Figure 1, FROM MODEL 1 (fixed 2026-09-28, was silently Model 5)
│   ├── Random_Intercepts_Overclaiming/Underclaiming/True_Engagement.png  # Supplementary, FROM MODEL 1
│   └── PPC_Genre_State_Proportions.png                 # Posterior predictive check (Model 1)
├── Tabs/
│   ├── Table_Model_Fit.html                # Formatted HTML comprehensive model fit table (5 specifications)
│   ├── Table_Overclaim.html                # Posterior parameter table for Overclaiming
│   ├── Table_True_Engagement.html          # Posterior parameter table for True Engagement
│   ├── Table_Underclaim.html               # Posterior parameter table for Underclaiming
│   └── Table_Wald_Tests.html               # Robust Bayesian Wald test summary
└── references.bib                         # BibTeX references for R, brms, cmdstanr, Stan, CmdStan
```

---

## Active Tasks & Completed Milestones
1. **Bayesian Model Hierarchy Complete:** All 5 Bayesian hierarchical specifications (Models 1–5) fully estimated on Hoffman2 cluster and synchronized locally.
2. **Convergence audit & refits complete (2026-09-28):** Models 2, 4, and 5 failed $\hat{R} < 1.01$ as originally sampled; refit with more draws/higher `adapt_delta`; all 5 now pass diagnostics. Always use the `_refit` `.rds` files for Models 2/4/5.
3. **Model selection corrected (2026-09-28):** The original 5-model comparison used invalid (marginal, not paired) WAIC standard errors. Recomputed via `loo::loo_compare()`: **Model 4 is preferred** (not Model 5 — they are statistically indistinguishable, and Model 4 has 20 fewer parameters). All genre-level figures were regenerated from Model 4.
4. **Figure 1 sourcing bug fixed (2026-09-28):** `Purged_Genre_Engagement_Profiles.png` had been silently generated from the random-slopes model despite the manuscript text describing it as coming from the pure-intercepts baseline (Model 1). Fixed; genre classification changed as a result (see §5 above).
5. **Sensitivity & robustness checks complete:** LKJ prior concentration (genre intercept-slope correlation), Winamp small-cell platform robustness, and fixed-effect prior width — all documented in a new **Limitations** section.
6. **Local manuscript source eliminated (2026-09-28):** `overclaiming_report.qmd` / `.html` deleted at user request. **The Google Doc is now the sole manuscript.** All future prose edits must be made directly against the Doc (see §6 above for the injection-script pattern).
7. **Google Drive Manuscript Synchronized:** Live Google Doc (*Liking/Listening Omnivore Data*) fully updated — corrected Table 5, Model 4-based Figures 4–6, Model-1-corrected Figure 1, and a new Limitations section (via `Scripts/inject_limitations_section.py`). Run `Rscript Scripts/sync_manuscript.R` whenever cached tables/figures change; use a bespoke injection script (modeled on `inject_limitations_section.py`) for new prose sections.
8. **Local execution safety lesson (2026-09-28):** loading multiple large (~120–600MB on disk, multi-GB in memory) `brmsfit` objects sequentially in one local R session caused repeated OOM freezes. **Rule going forward: never load more than one full model fit at a time locally; prefer isolated `Rscript` subprocesses (memory freed on exit) or run on Hoffman2 entirely, pulling back only small CSV/PNG artifacts.**
# Global Agent Guidelines

**Location:** `~/.config/agents/AGENTS.md` (Update this file to persist lessons globally across all projects)

## General Coding Standards
- Write concise, readable code with descriptive naming over short abbreviations.
- Prefer functional paradigms and immutable data structures where practical.
- Always include unit tests when introducing new utility functions or endpoints.

## Git & Workflow
- Format all commit messages using Conventional Commits (`feat:`, `fix:`, `refactor:`).
- Keep changes scoped to the prompt; do not refactor unrelated code.

## Safety & Boundaries
- Never commit hardcoded secrets, `.env` files, or private keys.
- Always run the repository's test and lint suites before signaling task completion.

## Quarto & Reporting Standards
- **Decoupled Compute & Fast Rendering Architecture (CRITICAL)**:
  - **Zero In-Document Model Execution**: Heavy statistical models (e.g., `brmsfit`, large MCMC posteriors, multi-gigabyte datasets) must **never** be loaded or sampled directly inside `.qmd` code chunks during compilation.
  - **Standalone Asset Serialization (`Plots/*.png`)**: Generate all figures via standalone, modular R extraction scripts (e.g., `scripts/generate_plots.R`, `scripts/extract_fixed_effects_stability.R`) and serialize publication-grade PNGs to `Plots/`. Reference them in `.qmd` using native markdown syntax (`![](Plots/my_figure.png){fig-align="center" width="100%"}`). This allows Pandoc to base-64 embed assets in milliseconds under `embed-resources: true` without invoking graphics device loops.
  - **Pre-Compiled Markdown Tables vs. Dynamic Table Engines**: Compute model fit comparisons, parameter estimates, and stability envelopes in extraction scripts, outputting them to `cache/*.csv` and embedding them as clean, static GitHub-flavored markdown tables in the `.qmd`. This completely bypasses heavy runtime HTML widget/table engines (`gt`, `kableExtra`, `DT`).
  - **Pure Pandoc AST Compilation**: Structuring the `.qmd` as pure Markdown/LaTeX without active `{r}` execution blocks allows Quarto to bypass knitr kernel startup, serializing multi-figure, multi-table reports to standalone HTML in under 2 seconds.
  - **Multi-Tiered Cache Architecture (`cache/`)**: Save intermediate tabular summaries and extracted draws to `cache/` (e.g., `fixed_effects_stability_summary.rds`, `random_slopes_stability_summary.rds`) so that modifying a specific figure only re-executes that single script without re-running the entire analytical pipeline.
- When rendering a Quarto document via the `bash` tool, be hyper-aware that rendering artifacts might trigger ghost file creation if Quarto writes to directories that are currently open in the editor or currently being crawled by background tasks.
- If using `<REPORT>` tags provided by the `report` skill, **do not manually duplicate** the `.qmd` file creation. The `<REPORT>` tags automatically serialize to disk. Mixing `cat > file.qmd` with `<REPORT>` output will create duplicate files (e.g. `file-1.qmd`) that break the `quarto render` logic.
- Avoid using `size` in `ggplot2` for line layers (`geom_line`, `geom_segment`, `geom_errorbar`); always use the modernized `linewidth` aesthetic to prevent deprecation warnings from cluttering the render logs.
- When applying robust standard errors to multi-state categorical models (like `nnet::multinom`), `lmtest::coeftest` struggles to return the structure. Manually extract the `vcovCL` diagonals and calculate the Z-scores and P-values via matrix arithmetic to ensure stable dataframe conversion.

## Supercomputing & HPC Integration (UCLA Hoffman2)
The local machine is fully configured to deploy computationally intensive R jobs (e.g., Bayesian mixture models, large simulations) to the **UCLA Hoffman2 Cluster**.

### Deployment Workflow
When asked to run a model on Hoffman2, you must do the following from the bash tool:
1. **Create the Project Directory on Hoffman2:**
   `ssh -o BatchMode=yes hoffman2 "mkdir -p my_project/Scripts my_project/dta"`
2. **Write the `.sh` Submit Script Locally:** (Use a standard Grid Engine `qsub` template)

### Grid Engine (.sh) Script Template
When writing `.sh` SGE submission scripts to run models on the cluster from scratch, ALWAYS use this exact structure to guarantee the toolchain compiles CmdStan flawlessly across array tasks and stays under the 24-hour limit:

```bash
#!/bin/bash
#$ -cwd
#$ -j y
#$ -o output_job.log
#$ -l h_rt=23:50:00   # CRITICAL: Always bound to just under 24 hours
#$ -l h_data=4G       # Tightly restrict RAM per core (e.g. 4G per core)
#$ -pe shared 4       # Number of cores

# CRITICAL: Must initialize the module system first in non-interactive Grid Engine shells
source /u/local/Modules/default/init/bash

# Must load modern GCC before R
module load gcc/10.2.0
module load R

# Pass allocated cores to R
export CMDSTANR_CORES=$NSLOTS
export cmdstanr_no_ver_check=TRUE

# Stagger concurrent array tasks by 15 mins to avoid compile races
if [ ! -z "$SGE_TASK_ID" ] && [ "$SGE_TASK_ID" -eq 2 ]; then
  sleep 900
fi

# Example R command:
Rscript Scripts/your_model.R
```
3. **Sync Data and Scripts via rsync:**
   `rsync -avz my_data.dta hoffman2:my_project/dta/`
   `rsync -avz Scripts/my_model.R Scripts/submit_job.sh hoffman2:my_project/Scripts/`
4. **Submit the Job via SSH:**
   `ssh -o BatchMode=yes hoffman2 "cd my_project && qsub Scripts/submit_job.sh"`

### Hoffman2 Best Practices & Gotchas
- **Cluster Hygiene (CRITICAL)**: Never run `qdel` on Hoffman2 unless you explicitly created the job ID yourself during your current session, or the user explicitly commands you to kill a specific ID. The user runs multiple concurrent jobs for different projects that must not be disrupted.
- **Queue Optimization (Avoiding Indefinite Waits & "Forever Queues")**: 
  - Hoffman2's maximum time limit for the general campus base pool is **24 hours**. Requesting `h_rt > 24:00:00` automatically traps the job in a permanent queue unless you have dedicated physical node hardware (`highp` queues). 
  - To maximize compute time while guaranteeing the fair-share backfill scheduler places your job:
    1. **Always bound time to just under the limit** (e.g., `#$ -l h_rt=23:50:00`).
    2. **Tightly restrict memory to exactly what is needed per core** (e.g., `#$ -l h_data=3G` when using 16 cores) to ensure the total footprint doesn't block the scheduler.
  - *Note on Checkpointing:* While standard jobs can checkpoint and resume, `brms` (NUTS sampler) cannot resume NUTS adaptation mid-warmup. Thus, you must allocate sufficient cores (`threading(4)`) to ensure the model finishes within the 24-hour limit.
- **Array Job Strategies**: For iterating across independent datasets or running sequential model blocks rapidly, use Array Jobs (e.g., `#$ -t 1-N` or `run_on_hoffman script.R 8 12 4G 1-10`). This slices large requests into smaller chunks that backfill through the queue instantly.
  - *Staggering Locks*: When submitting an Array Job to a fresh environment, concurrent tasks will race to write to the `renv/library` directory, causing a `00LOCK-renv` crash. Always add a bash `sleep` stagger in the submit script (e.g., `sleep $(( (SGE_TASK_ID - 1) * 600 ))`) so Task 1 can finish building the library before subsequent tasks wake up.
- **Bypassing Obscure renv Compilation Crashes & CmdStan Linker Errors**: When restoring a massive project lockfile from source on Hoffman2, obscure downstream dependencies (like `QuickJSR`, `bslib`, or HTML widgets) often fail to compile and crash the entire pipeline. For raw modeling runs, bypass `renv::restore()` in the SGE script entirely. Instead, use base R to manually `install.packages('brms')` and `cmdstanr`. **CRITICALLY**, if you see Intel TBB linker errors (`undefined reference to tbb::interface...`) during model compilation, it means a stale `~/.cmdstan` directory was compiled under a different toolchain. Force a native compilation with `overwrite = TRUE` so CmdStan links against the currently loaded `gcc/10.2.0` and `tbb` modules. **However, in an Array Job, NEVER let all tasks run this concurrently** (they will overwrite and delete each other's source files). Wrap the call so only Task 1 performs the installation (`if(as.integer(Sys.getenv("SGE_TASK_ID", 1)) == 1) { cmdstanr::install_cmdstan(...) }`), and ensure the bash `sleep` stagger for subsequent tasks is at least 10 minutes (`600` seconds) so compilation finishes.
- **C++ Compilation Errors**: Hoffman2's default `R` module uses an outdated 2015 compiler (`gcc-4.8.5`). If you manually install packages on the cluster (or if `renv::restore()` is running), you *must* load a modern compiler (e.g., `module load gcc/10.2.0`) before loading R. Also load `module load cmake` to prevent `RcppParallel` installation failures. The `run_on_hoffman` script handles this automatically, preventing notorious C++11 literal spacing errors (e.g., `operator""_xl`) when compiling packages like `tidyr`, `dplyr`, or `brms`.
- **Bulletproof Hoffman2 SGE Template for brms**: When writing `.sh` SGE submission scripts to run models on the cluster from scratch, ALWAYS use this exact structure to guarantee the toolchain compiles CmdStan flawlessly across array tasks:
  ```bash
  # Must load modern GCC before R
  source /u/local/Modules/default/init/bash
  module load gcc/10.2.0
  module load R

  # CRITICAL: Prevent Hoffman's global TBB module from overriding CmdStan's internal TBB
  
  
  # CRITICAL: Stagger concurrent tasks by at least 15 minutes (900 seconds) 
  # so Task 1 can cleanly compile both CmdStan AND the first brms C++ model 
  # without Task 2 racing it to delete shared temporary compiler objects (e.g. main_threads.o)
  if [ "$SGE_TASK_ID" -eq 2 ]; then
    sleep 900
  fi
  
  # Pass allocated cores to R
  export CMDSTANR_CORES=$NSLOTS
  
  # CRITICAL: DO NOT export CMDSTAN in bash! If the directory is missing/empty, 
  # cmdstanr's .onLoad sequence crashes with an obscure `endsWith()` error.
  # Instead, export only the version check skip, and set the path safely inside R.
  export cmdstanr_no_ver_check=TRUE
  
  # Ensure ONLY Task 1 installs the CmdStan backend natively. 
  # Pin version to 2.33.1 to avoid the stanc --name bug with brms.
  # Force overwrite to avoid TBB linker crashes from stale builds.
  Rscript -e "
    options(repos = c(CRAN = 'https://cloud.r-project.org'))
    if (!requireNamespace('brms', quietly = TRUE)) install.packages('brms')
    if (!requireNamespace('cmdstanr', quietly = TRUE)) install.packages('cmdstanr', repos = c('https://mc-stan.org/r-packages/', getOption('repos')))
    
    # Load library FIRST, then set the path safely inside R
    library(cmdstanr)
    cmdstanr::set_cmdstan_path('~/.cmdstan/cmdstan-2.33.1')
    
    if(as.integer(Sys.getenv('SGE_TASK_ID', 1)) == 1) { 
      cmdstanr::install_cmdstan(version = '2.33.1', cores = Sys.getenv('NSLOTS', unset = 4), overwrite = TRUE) 
    }
  "
  Rscript Scripts/your_model.R
  ```
- **Dynamic Threads**: R scripts submitted to Hoffman must dynamically read `$NSLOTS` (e.g., `Sys.getenv("CMDSTANR_CORES")`) and calculate `threads_per_chain = floor(NSLOTS / 4)` to ensure `brms` fully utilizes the allocated node without sitting idle.
- **Authentication & SSH Config**: Passwordless SSH is fully configured for Hoffman2. The config file is located at `~/.ssh/config` (which sets the `hoffman2` alias, username `olizardo`, and keep-alive intervals). It relies on the `ed25519` cryptographic keys in the same `~/.ssh/` directory. AI agents MUST seamlessly use `ssh -o BatchMode=yes hoffman2 "command"` to directly interact with the cluster without prompting the user. Do not alter this configuration.

## R & Bayesian Modeling Practices
- **mclogit & mblogit**: 
  - When specifying crossed random effects in `mclogit::mblogit`, you **must** pass them as a list (e.g., `random = list(~ 1|id, ~ 1|genre_id)`). Using the `lme4` syntax (`~ 1|id + 1|genre_id`) will crash with a `model frame and formula mismatch in model.matrix()` error.
- **Handling `renv` Sync Issues**:
  - When using Quarto/RMarkdown documents that require external compilation engines (like `rmarkdown` or `knitr`), ensure those packages are explicitly installed and snapshotted (`renv::install("rmarkdown"); renv::snapshot()`). Even if the scripts don't directly `library(rmarkdown)`, the `renv` environment requires them to render documents properly.
  - **Implicit Dependencies (e.g., `cmdstanr`)**: If a package is only passed as a string argument (e.g., `backend = "cmdstanr"` in a `brms::brm()` call), `renv`'s dependency discovery will miss it. Always add `library(cmdstanr)` explicitly at the top of your script before running `renv::snapshot()`. Otherwise, remote cluster runs using `renv::restore()` will fail because the package is absent from the lockfile.
- **Bayesian Mixture Models (brms)**:
  - **Label Switching**: Finite mixture models in Stan suffer from "label switching." Always apply ordered constraints (e.g., `order = "mu"`) when defining the mixture families to ensure chains converge to the same latent classes.
  - **Posterior Collapse (Random vs. Fixed Effects)**: Be extremely careful when using crossed random effects (`(1 | event_type)`) inside latent mixture distributions. Highly dense parameter spaces can cause the sampler to "give up" (shrink variance to zero), leading to posterior collapse and erasing group heterogeneity. Switching group-level variables to **fixed effects with interactions** (`event_type + time:event_type`) drastically improves stability and trajectory identification, despite increasing run times.
  - **Model Comparison (LOO vs WAIC & Socket Timeouts)**: While LOO-CV (`add_criterion(fit, "loo")`) is theoretically preferred over WAIC or information criteria (AIC/BIC) for finite mixture models (as the mathematical proofs for AIC/BIC break down in bounded mixture spaces), computing exact or approximate LOO-CV on complex models with many cores (e.g., 16) causes `parallel::makePSOCKcluster()` to crash with network socket timeouts on HPC nodes, destroying the model object *after* sampling completes but *before* saving. 
    - **Crucial Rule:** If you must use LOO, strictly limit it to `cores = 4` or fewer (e.g., `add_criterion(fit, "loo", cores = min(num_cores, 4))`). Alternatively, fall back to `WAIC` (`add_criterion(fit, "waic")`) to drastically reduce memory usage and completely bypass parallel socket timeouts.
    - **Crucial Rule 2 (Atomic Saving & Wall Limits):** NEVER chain NUTS sampling and `add_criterion()` in memory on HPC clusters. ALWAYS use the `file = "..."` argument natively inside `brm()` so the multi-hour posterior samples are immediately and atomically serialized to disk the second sampling finishes. Only *after* `brm()` saves the file should you call `add_criterion()` to compute fit statistics. This ensures that if the LOO/WAIC calculation crashes or hits an HPC 24h wall limit, the raw posterior draws are perfectly preserved.
  - **Adjacent Category Dispersion**: When fitting `brms` Adjacent Category models (`family = acat()`) that model variance/dispersion (`disc ~ ...`), the response variable *must* be an explicit `ordered` factor (e.g., `ordered(y)`). Unordered factors or integers will cause `brms` to crash during internal Stan data compilation.
- **Local vs Remote Execution**: Never accidentally include HPC-bound heavy models (like variance/dispersion SGE jobs) in local background queues (e.g., `systemd`). This will silently hang or starve the local machine. Strictly separate local queues from Hoffman submission scripts.


## Google Drive & Word Manuscript Table / Figure Synchronization
For projects where manuscripts, tables, and figures are synced with Google Drive / Microsoft Word (`.docx`):

### 1. The Google Drive In-Place Injection Pipeline (CRITICAL)
- **Zero Style Disruption**: To completely preserve the live manuscript's typography, fonts, heading hierarchy, margins, line spacing, track changes, and collaborator comments, **never re-upload or overwrite the whole document via Pandoc conversion**.
- **The Drive Round-Trip Protocol**:
  1. Download the live draft via `googledrive::drive_download(as_id(DOC_ID), path = "draft.docx", overwrite = TRUE)`.
  2. Perform surgical XML injection on `word/document.xml`, `word/_rels/document.xml.rels`, and `word/media/` locally.
  3. Upload the updated document directly back to Drive via `googledrive::drive_update(as_id(DOC_ID), media = "draft_updated.docx")`.
- **Two Update Modes (Initial Insertion vs. Automatic Re-Sync)**:
  - **Initial Tag Injection**: Authors place tags wrapped in double curly braces where assets belong (e.g., `{{TABLE_1}}` or `{{PLOT_FOREST_M7}}`). The script replaces the tag paragraph with the native OpenXML table or plot image.
  - **Automated Caption-Anchored Updates (No Re-Tagging Required)**: Once a table or figure is in the document, subsequent model/data updates do **not** require re-inserting tags. The script automatically matches standard captions (e.g., `Table 1.`, `Figure 2.`) and replaces the adjacent `<w:tbl>` or `<w:drawing>` in-place with the latest version.

### 2. OpenXML Schema Compliance & Character Escaping Rules (Preventing 400 Bad Request)
- **Mandatory XML Character Escaping**: All text inserted into table cells, headers, or captions **must** be XML-escaped (`<` to `&lt;`, `>` to `&gt;`, `&` to `&amp;`, `"` to `&quot;`). For example, unescaped p-values like `<0.001` produce `<w:t><0.001</w:t>`, which corrupts the XML syntax and causes Google Drive's import filter to fail with `400 Bad Request`.
- **Strict ECMA-376 Tag Ordering**:
  - Inside `<w:pPr>`: `<w:suppressAutoHyphens/>` -> `<w:spacing/>` -> `<w:ind/>` -> `<w:jc/>`. (Out-of-order elements violate XML schemas and trigger upload errors).
  - Inside `<w:tcPr>`: `<w:tcW/>` -> `<w:tcBorders/>` -> `<w:noWrap/>`.

### 3. Figure Injection, Relationship Mapping & Exact Aspect Ratios
- **Strict Relationship Tracing**: In OpenXML, drawing elements (`<w:drawing>`) reference image files via relationship IDs (`r:embed="rIdX"`). Never assume the order of `rId`s matches the order of `imageX.png` files or figure appearance. Always parse `word/_rels/document.xml.rels` to map `rIdX` -> `media/imageY.png` and confirm with the adjacent caption text (`Figure 1.`, `Figure 2.`).
- **Dual DrawingML Extent Synchronization**: When updating an image, **both** `<wp:extent cx="..." cy="..."/>` and `<a:ext cx="..." cy="..."/>` in `word/document.xml` **must** be updated simultaneously to match the image's exact native aspect ratio:
  - Width is set to full printable text width ($6.5 	ext{ inches} = 5,943,600 	ext{ EMUs}$).
  - Height in EMUs: $	ext{height\_EMU} = 	ext{round}(5,943,600 	imes (	ext{pixel\_height} / 	ext{pixel\_width}))$.
  - Failing to synchronize extents causes Google Docs to stretch/squish images into old container dimensions.

### 4. Universal APA Table Style & Formatting Standards (MANDATORY)
All manuscript tables injected into Google Docs / Word documents across all projects must strictly conform to these formatting specifications:

1. **Width & Proportional Column Allocations**:
   - Total table width must scale to full **6.5-inch printable portrait width** (`w:w="9360" w:type="dxa"`).
   - **Column 1 (Row Labels)**: Must be allocated wider space (~36–45% of total table width) to prevent awkward multi-line text wrapping on variable names.
   - **Numeric / Statistic Columns**: Remaining table width is divided equally across all subsequent columns.
   - Define exact `<w:gridCol w:w="..."/>` in `<w:tblGrid>` and `<w:tcW w:w="..." w:type="dxa"/>` on each table cell.

2. **Anti-Word-Break & Hyphenation Controls (Fit Whole Words to Columns)**:
   - **No Mid-Word Splitting**: Every paragraph inside table cells must include `<w:suppressAutoHyphens/>` in `<w:pPr>` to strictly prevent words from breaking or hyphenating mid-word across lines.
   - **No Wrap on Numbers**: Include `<w:noWrap/>` in `<w:tcPr>` for all numeric/statistic cells so numbers, estimates, and confidence intervals stay strictly on a single line.

3. **Horizontal Text Alignment**:
   - **Column 1 (Row Labels)**: Strictly left-justified (`<w:jc w:val="left"/>`).
   - **All Other Columns (Estimates, Statistics, Percentages)**: Strictly center-justified (`<w:jc w:val="center"/>`).

4. **Pagination & Page Break Controls**:
   - **Row Protection**: Every table row (`<w:trPr>`) must include `<w:cantSplit/>` to prevent individual rows from being sliced across page breaks.
   - **Repeating Header Rows**: The header row must include `<w:tblHeader/>` so column headers repeat automatically when a table spans multiple pages.

5. **Paragraph Indentations & Spacing**:
   - **Zero Indentation**: Strip all paragraph indentations from inside the table environment (`<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`).
   - **Tight Vertical Spacing**: Set zero before/after paragraph spacing (`<w:spacing w:before="0" w:after="0"/>`).

6. **Decimal Precision & Number Formatting**:
   - **Percentages**: Format strictly to **1 decimal place** (e.g., `79.9%`, `65.4%`).
   - **Model Estimates & Odds Ratios**: Format strictly to **2 decimal places** (e.g., `0.35`, `1.42`, `-0.18`), with directional significance bolding where appropriate.
   - **Standard Errors / Confidence Intervals**: Format strictly to **2 decimal places** (e.g., `(0.04)`).
   - **Sample Sizes (N, J)**: Format as integers with comma separators (e.g., `10,695`).

7. **APA 7th Horizontal Borders & Cell Padding**:
   - **Horizontal Rules**: 1pt top border (`sz="8"`), 0.5pt header-bottom border (`sz="4"`), 1pt table-bottom border (`sz="8"`).
   - **Zero Vertical Borders**: Set vertical and interior vertical borders to `w:val="none"`.
   - **Cell Padding (Margins)**: Top and bottom padding set to `120` dxa (6pt); left and right padding set to `160` dxa (8pt).

8. **Cross-Group & Multi-Category Layout (Vertically Stacked Panels vs. Horizontal Compression)**:
   - **Avoid Horizontal Squeezing**: When comparing multiple groups (e.g., countries, cohorts, experimental arms) across several categorical levels, avoid laying out groups side-by-side across columns (which creates 7–11 narrow columns under 0.6 inches wide, causing severe text compression and awkward wrapping).
   - **Vertically Stacked Panels**: Stack groups vertically as distinct panels (*Panel A: United States*, *Panel B: United Kingdom*) sharing the same top column headers. Use a full-width spanning section header row (`<w:gridSpan w:val="N"/>`) with bold/italic title (`<w:b/><w:i/>`), and indent sub-item row labels in Column 1 (`<w:ind w:left="140"/>`). This keeps table width restricted to 4–6 spacious columns (0.9–2.3 inches each).

9. **Model Parameter Column Naming**:
   - In model fit and specification comparison tables, standardly name the parameter count column **`N. Par`** (rather than `Params` or `Parameters`) to maintain concise, consistent APA presentation.

### 5. Authentication
- Use `googledrive::drive_auth(email = "omarlizardo@gmail.com")`. Cached gargle tokens in `~/.cache/gargle/` provide seamless, non-interactive authentication.

### 6. Turnkey Python & R In-Place Injection Template
To recreate this workflow in any project from scratch, use the following standardized pattern:

#### Step 1: Download Live Manuscript (R)
```r
library(googledrive)
drive_auth(email = "omarlizardo@gmail.com")
drive_download(as_id(DOC_ID), path = "draft_live.docx", overwrite = TRUE)
```

#### Step 2: In-Place XML Injection Script (`update_manuscript.py`)
```python
import zipfile
import re
import xml.etree.ElementTree as ET

# --- Standard APA Table Generator ---
def create_apa_table_xml(headers, rows_data, col_widths=None):
    total_w = 9360  # 6.5 in printable area in dxa
    num_cols = len(headers)
    if col_widths is None:
        col1_w = int(total_w * 0.40)
        rem_w = total_w - col1_w
        sub_w = int(rem_w / (num_cols - 1))
        col_widths = [col1_w] + [sub_w] * (num_cols - 2)
        col_widths.append(total_w - sum(col_widths))
        
    xml = [f'<w:tbl><w:tblPr><w:tblW w:w="{total_w}" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:left w:val="none"/><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders><w:tblCellMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>']
    for w in col_widths: xml.append(f'<w:gridCol w:w="{w}"/>')
    xml.append('</w:tblGrid>')
    
    # Header Row
    xml.append('<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>')
    for i, h in enumerate(headers):
        align = "left" if i == 0 else "center"
        xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:tcBorders><w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/></w:tcBorders><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>{h}</w:t></w:r></w:p></w:tc>')
    xml.append('</w:tr>')
    
    # Data Rows
    for row in rows_data:
        xml.append('<w:tr><w:trPr><w:cantSplit/></w:trPr>')
        for i, val in enumerate(row):
            align = "left" if i == 0 else "center"
            xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr><w:r><w:t>{val}</w:t></w:r></w:p></w:tc>')
        xml.append('</w:tr>')
    xml.append('</w:tbl>')
    return "".join(xml)

# --- Vertically Stacked Panel APA Table Generator ---
def create_panel_table_xml(headers, panels_dict, col_widths):
    total_w = 9360
    xml = [f'<w:tbl><w:tblPr><w:tblW w:w="{total_w}" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:left w:val="none"/><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders><w:tblCellMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>']
    for w in col_widths: xml.append(f'<w:gridCol w:w="{w}"/>')
    xml.append('</w:tblGrid>')
    
    # Header Row
    xml.append('<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>')
    for i, h in enumerate(headers):
        align = "left" if i == 0 else "center"
        xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:tcBorders><w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/></w:tcBorders><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>{h}</w:t></w:r></w:p></w:tc>')
    xml.append('</w:tr>')
    
    # Panels
    for p_idx, (panel_title, rows) in enumerate(panels_dict.items()):
        # Full-width panel header row
        xml.append(f'<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr><w:tcW w:w="{total_w}" w:type="dxa"/><w:gridSpan w:val="{len(headers)}"/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="{"60" if p_idx==0 else "160"}" w:after="60"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="left"/></w:pPr><w:r><w:rPr><w:b/><w:i/></w:rPr><w:t>{panel_title}</w:t></w:r></w:p></w:tc></w:tr>')
        # Sub-item rows with Column 1 indented
        for row in rows:
            xml.append('<w:tr><w:trPr><w:cantSplit/></w:trPr>')
            for i, val in enumerate(row):
                align = "left" if i == 0 else "center"
                ind = ' w:left="140"' if i == 0 else ' w:left="0"'
                xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind{ind} w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr><w:r><w:t>{val}</w:t></w:r></w:p></w:tc>')
            xml.append('</w:tr>')
    xml.append('</w:tbl>')
    return "".join(xml)

# --- Main Injection Function ---
def inject_assets(in_docx, out_docx, table_dict, image_dict=None):
    with zipfile.ZipFile(in_docx, "r") as zin, zipfile.ZipFile(out_docx, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if image_dict and item.filename in image_dict:
                with open(image_dict[item.filename], "rb") as f: data = f.read()
            elif item.filename == "word/document.xml":
                text = zin.read(item.filename).decode("utf-8")
                for caption_str, tbl_xml in table_dict.items():
                    pattern = re.compile(rf'(<w:p[^>]*>(?:(?!<w:p).)*?{re.escape(caption_str)}.*?</w:p>\s*)(<w:tbl.*?</w:tbl>)', re.DOTALL)
                    if pattern.search(text):
                        text = pattern.sub(r'\1' + tbl_xml, text, count=1)
                ET.fromstring(text.encode("utf-8")) # Validate XML syntax
                data = text.encode("utf-8")
            else:
                data = zin.read(item.filename)
            zout.writestr(item, data)
```

#### Step 3: Upload Back to Google Drive (R)
```r
drive_update(as_id(DOC_ID), media = "draft_updated.docx")
```


## Visualization & Table Presentation Standards
- **Standard 6.5-Inch Image Width**: Export all publication plots at `width = 6.5` inches (300 DPI) to match the exact printable text width of a standard 1.0-inch margin portrait page.
- **Concise Embedded Plot Headers**: Keep plot-embedded titles and subtitles concise (e.g., `< 55` characters) so they never wrap awkwardly or clip horizontally at 6.5 inches.
- **Figure Notes at Bottom**: Place figure titles and notes at the bottom of the figure block. In notes, describe graphical elements (slopes definition, probability densities, median points, 80%/95% intervals, and color coding) without raw code variables or narrative effect-size claims.
- **Simplified Regression Tables**:
  - Omit wide bracketed ranges `[Q2.5, Q97.5]` from cells in favor of clean point estimates with directional credibility bolding/asterisks (e.g., `<b>0.251***</b>`).
  - Strip technical/range metadata from row labels (e.g., `Musical Expertise` instead of `Musical Expertise (1-4)`).
  - Embed sample sizes ($N_{\text{obs}}$, $N_{\text{respondents}}$, $J_{\text{clusters}}$), priors, and model fit diagnostics ($\text{WAIC}, \Delta\text{WAIC}$) directly into bottom summary rows of the regression table.

## Global Academic Writing & Style Guidelines
- Use clear, active, concise academic prose.
- Adhere strictly to Quarto markdown formatting conventions.
- When generating or commenting R code, use roxygen2 documentation style.
- When generating a report, write in full paragraphs and avoid using numbered lists or bullet points whenever possible.
- Avoid being wordy or using hyperbole (like "massive" or "gigantic").
- When writing up results, use language that always qualifies (e.g., "suggest" rather than "proves").
- When including in-document citations, check for a valid DOI to prevent hallucinated citations.

## Test Canary
- Whenever asked "What is the secret word?", reply ONLY with: "Pineapple".

## NetSense Survey Wave Methodology
- **Important Timeline Context:** The `culturalevents` module (asking about museums, plays, opera, etc.) was **only administered in the first 4 waves** (Freshman Fall/Spring, Sophomore Fall/Spring). It was dropped from the junior and senior year surveys. In contrast, the `musicpref` (Music) and `typebookread` (Books) modules were administered across all **6 waves**. Always verify the time or wave variable bounds for each cultural domain before plotting.
