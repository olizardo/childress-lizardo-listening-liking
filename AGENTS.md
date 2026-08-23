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
1. **Model 1 (Crossed Random Intercepts):** `(1 | id) + (1 | genre_id)` across all logits $\rightarrow$ `rds/model_brms_intercepts.rds` (WAIC = 48,917.4, df = 4,820). Serves as the baseline model for omnibus Joint Wald test statistics, fixed-effect parameter tables, and predicted probability plots.
2. **Model 2 (Constrained Slopes — Like Only):** Random slopes `(1 + child_arts | genre_id)` strictly on `muLikeOnly`, with random intercepts on `muListenOnly` and `muBoth` $\rightarrow$ `rds/model_brms_constrained_likeonly.rds` (WAIC = 48,823.9, df = 4,840).
3. **Model 3 (Constrained Slopes — Under- & Overclaim):** Random slopes `(1 + child_arts | genre_id)` on `muListenOnly` and `muLikeOnly`, with random intercepts strictly on `muBoth` $\rightarrow$ `rds/model_brms_constrained_under_over.rds` (WAIC = 48,822.1, df = 4,860).
4. **Model 4 (Constrained Slopes — Overclaiming & Consistent):** Random slopes `(1 + child_arts | genre_id)` on `muLikeOnly` and `muBoth`, with random intercepts strictly on `muListenOnly` $\rightarrow$ `rds/model_brms_constrained_over_true.rds` (WAIC = 48,735.1, df = 4,860).
5. **Model 5 (Full Crossed Random Slopes — Preferred):** `(1 | id) + (1 + child_arts | genre_id)` across all logits $\rightarrow$ `rds/model_brms_slopes.rds` (WAIC = **48,732.4**, df = 4,880). Preferred model for genre-level slope variance and counterfactual predictions.

### 4. Bayesian Model Selection & Fit Hierarchy

| Model Specification | Underclaim (Listen Only) | Overclaim (Like Only) | Consistent (Both) | Parameters ($df$) | $\text{elpd}_{\text{waic}}$ ($SE$) | WAIC ($SE$) | $\Delta$WAIC (vs. Baseline) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Crossed Random Intercepts** | — | — | — | 4,820 | -24,458.7 (115.2) | 48,917.4 (230.4) | 0.0 |
| **2. Constrained Slopes (Like Only)** | — | ✓ | — | 4,840 | -24,412.0 (114.8) | 48,823.9 (229.6) | -93.5 |
| **3. Constrained Slopes (Under- & Overclaim)** | ✓ | ✓ | — | 4,860 | -24,411.0 (114.7) | 48,822.1 (229.5) | -95.3 |
| **4. Constrained Slopes (Overclaiming & Consistent)** | — | ✓ | ✓ | 4,860 | -24,367.5 (114.7) | 48,735.1 (229.5) | -182.3 |
| **5. Full Crossed Random Slopes (Preferred)** | ✓ | ✓ | ✓ | 4,880 | -24,366.2 (114.3) | **48,732.4** (228.6) | **-185.0** |

- **Optimal Predictive Fit:** Model 5 (Full Crossed Random Slopes) achieves the greatest predictive improvement ($\Delta\text{WAIC} = -185.0$ vs. the random intercepts baseline), demonstrating that early arts exposure exerts distinct, genre-specific slopes across complex tastes.
- **Substantive Hierarchy:** Adding slopes on `LikeOnly` accounts for roughly half of the total fit gain ($\Delta\text{WAIC} = -93.5$), while adding slopes to `ListenOnly` in Model 3 adds almost nothing ($\Delta = -1.8$). Model 4 (slopes on both `LikeOnly` and `Both`) captures virtually the entire remaining gain ($\Delta\text{WAIC} = -182.3$), confirming that cultural capital slopes matter profoundly for consistent consumption (`Both`) alongside overclaiming (`LikeOnly`), with minimal variation on ambient listening (`ListenOnly`).

### 5. Key Empirical Findings
- **Highbrow Concentration:** Immersion in childhood arts increases the odds of overclaiming Opera by **15.2-fold** (95% CrI: [8.46, 28.25]) and Classical music by **12.0-fold** (95% CrI: [7.07, 20.18]). In contrast, Country is the only genre where the 95% credible interval crosses unity ($\text{OR} = 1.07$, 95% CrI: [0.61, 1.82]).
- **Educational Prestige Governs Overclaiming:** Bayesian overclaiming odds ratios correlate exceptionally strongly with Class Prestige (the College/HS liking ratio; $r = 0.79$, Spearman $\rho = 0.70$).
- **Negative Intercept-Slope Correlation:** Genre random intercepts ($u_0$) and arts random slopes ($u_1$) for overclaiming correlate at $r = -0.83$ ($\rho = -0.82$). Lower-popularity highbrow genres experience the steepest positive boost from cultural capital.
- **Corrected Genre Profiles:** Within-genre centered random intercepts ($\Delta u_{0jk} = u_{0jk} - \bar{u}_{0j}$) cancel the baseline popularity artifact ($P(\text{Neither})$ denominator effect), revealing clear qualitative clusters using the directional credibility rule ($\text{pd} \ge 0.95$):
  - *Overclaiming Tilt:* Bluegrass, Oldies, Musicals, Easy Listening, Jazz, Swing/Big Band, Opera.
  - *Consistent Tilt:* Classic Rock, Country, Contemporary Rock, Contemporary Pop, Oldies.
  - *Underclaiming Tilt:* Latin, Rap/Hip Hop, Heavy Metal, Contemporary Pop.
- **Predicted Probability Shift (Baseline Model):** Moving from childhood arts exposure level 1 to 7 increases the predicted probability of Overclaiming from **19.4%** to **45.7%** (+26.3 pp), while Consistent Engagement rises modestly from **9.0%** to **12.5%** (+3.5 pp), Underclaiming declines from **11.1%** to **6.0%**, and non-engagement (*Neither*) drops from **59.5%** to **34.9%**.
- **Monochrome Publication Styling:** All summary tables (`gt`) adhere to a clean academic journal theme with serif typography, standardized horizontal rules, and zero decorative color fills.
- **Reproducibility & Environment:** Full bibliography integration via `references.bib` citing R v4.5.3, `brms` v2.23.0, and `CmdStan` v2.39.0 / `cmdstanr`, with `renv` environment fully locked and synchronized.

---

## Directory & File Structure

```
.
├── Scripts/
│   ├── run_brms_intercepts.R               # Bayesian random intercepts model
│   ├── submit_brms_intercepts.sh           # SGE 16-core submit wrapper
│   ├── run_brms_slopes.R                   # Bayesian full random slopes model
│   ├── submit_brms_slopes.sh               # SGE 16-core submit wrapper
│   ├── run_brms_constrained.R              # Bayesian constrained LikeOnly slopes model
│   ├── submit_brms_constrained.sh          # SGE 16-core submit wrapper
│   ├── run_brms_constrained_under_over.R   # Bayesian constrained Under/Over slopes model
│   ├── submit_brms_constrained_under_over.sh # SGE 16-core submit wrapper
│   ├── run_brms_constrained_over_true.R    # Bayesian constrained Over/True slopes model
│   ├── submit_brms_constrained_over_true.sh # SGE 16-core submit wrapper
│   ├── plot_purged_random_intercepts.R     # Composite 3-panel within-genre centered profiles (pd >= 0.95)
│   ├── plot_correlations.R                 # Prestige and Intercept-Slope correlation figures with high repel
│   ├── plot_odds_overclaiming_halfeye.R    # Tidybayes half-eye plot of arts exposure odds ratios
│   ├── fixed_multinomial_model.R           # Local multinom baseline
│   ├── clean_artistgenre.R                 # Artist-to-genre classification
│   └── analysis_time.R                     # Long-format data preparation
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
│   ├── model_brms_intercepts.rds           # Bayesian random intercepts fit (121 MB)
│   ├── model_brms_slopes.rds               # Bayesian full random slopes fit (123 MB)
│   ├── model_brms_constrained_likeonly.rds # Bayesian constrained LikeOnly fit (122 MB)
│   ├── model_brms_constrained_under_over.rds # Bayesian constrained Under/Over fit (118 MB)
│   ├── model_brms_constrained_over_true.rds # Bayesian constrained Over/True fit (244 MB)
│   ├── waic_brms_constrained.rds           # WAIC object for LikeOnly constrained model
│   ├── waic_brms_constrained_under_over.rds # WAIC object for Under/Over constrained model
│   ├── waic_brms_constrained_over_true.rds # WAIC object for Over/True constrained model
│   ├── robust_vcov_twoway.rds              # Two-way cluster-robust covariance matrix
│   ├── ame_genre_fixed.rds                 # AME calculations across all states
│   └── ame_genre_constrained.rds           # Constrained LikeOnly AME dataframe
├── Plots/
│   ├── Bayesian_Odds_Prestige_Correlation.png # Educational prestige vs. Bayesian odds ratio correlation (High repel)
│   ├── ChildArts_Effects_Bayesian_CrI.png    # Predicted probabilities across arts exposure levels (Harmonized theme & palette)
│   ├── ChildArts_Odds_Overclaiming_HalfEye.png # Tidybayes half-eye plot of arts exposure odds ratios
│   ├── Overclaim_Random_Intercept_Slope_Correlation.png # Random intercept vs slope negative correlation (High repel)
│   └── Purged_Genre_Engagement_Profiles.png # Composite 3-panel within-genre centered engagement profiles (pd >= 0.95)
├── Tabs/
│   ├── Table_Model_Fit.html                # Formatted HTML comprehensive model fit table (5 specifications)
│   ├── Table_Overclaim.html                # Posterior parameter table for Overclaiming
│   ├── Table_True_Engagement.html          # Posterior parameter table for True Engagement
│   ├── Table_Underclaim.html               # Posterior parameter table for Underclaiming
│   └── Table_Wald_Tests.html               # Robust Bayesian Wald test summary
├── references.bib                         # BibTeX references for R, brms, cmdstanr, Stan, CmdStan
├── overclaiming_report.qmd                 # Master Quarto report (Full academic prose, 0 bullets/lists)
└── overclaiming_report.html                # Rendered HTML document (31 chunks, clean build)
```

---

## Active Tasks & Completed Milestones
1. **Bayesian Model Hierarchy Complete:** All 5 Bayesian hierarchical specifications (Models 1–5) fully estimated on Hoffman2 cluster and synchronized locally.
2. **Model Selection Confirmed:** Model 4 and Model 5 demonstrate that genre-level random slopes for childhood arts exposure operate primarily on Overclaiming and True Engagement, with negligible slope variance on Underclaiming.
3. **Master Report Synchronized:** `overclaiming_report.qmd` fully updated with complete 5-model fit comparison table and narrative.
