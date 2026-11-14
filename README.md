# Overclaiming in Musical Tastes: Replication Package

Survey respondents state liking for a genre in the abstract while that genre is
absent from the artists and songs in their recent playlists. This repository
reproduces the analysis for 1,450 respondents crossed with 20 genres (28,655
person-genre rows): Bayesian crossed random-effects multinomial logits fitted
with `brms` on CmdStan.

Every manuscript table and figure traces to a script listed below. The
manuscript itself is a Google Doc and is not in this repository.

## Layout

- `dta/` — analysis data. `genresobjects.dta` (hand-coded artists) →
  `genresobjects_processed.dta` → `analysis_model_input.dta` (long person-genre
  model input); `analysis_time_CCC.dta` supplies the respondent-level covariates.
- `Scripts/` — data preparation, model fits, diagnostics, sensitivity checks,
  and every table and figure script.
- `Tabs/` — manuscript tables, one markdown file each.
- `Plots/` — manuscript figures, named by figure number (`fig{N}_{topic}.png`).
- `cache/` — the CSVs and markdown tables the table and figure scripts write;
  `Tabs/` files are copies of these.
- `docs/` — codebooks and survey instruments.
- `rds/` — fitted model objects and WAIC objects (gitignored, kept locally).
- `renv.lock`, `renv/` — locked R package environment.

## Environment

Local: R 4.5.3, `brms` 2.23.0, CmdStan 2.33.1 (via `cmdstanr`), restored with
`renv::restore()`. The full fits need more memory than a laptop has; the fits
in this paper were run on Hoffman2 with

```
module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
```

Size the job by what it loads, not by what it samples. Sampling survives a few
GB, but computing WAIC or loading a second fit does not, so fits, WAIC and
`/loo` jobs use `--mem=48G`, and extraction jobs that load one fit use 24–40 GB.
Never load two full `brmsfit` objects in one R process.

## Reproduction order

1. **Genres.** `Scripts/prep_artistgenre.R` rebuilds the artist-to-genre codes
   and writes `dta/genresobjects_processed.dta`. It needs `dta/genresobjects.dta`
   and `csv/to inc.csv` (the hand-coded inclusion list), which is **not** in the
   repository; restore it before rerunning this step. Its output is already in
   `dta/`, so every later step runs without it.
2. **Model input.** `Scripts/prep_model_input.R` splices the rebuilt
   `genre_final1-10` and `stream_source` columns into the respondent file and
   writes `dta/analysis_model_input.dta`. The `genre_final*` columns inside
   `analysis_time_CCC.dta` are shuffled across respondents and are always
   overwritten here; never read them from that file.
3. **Fits.** One script per specification; each writes its fit and a WAIC object
   to `rds/`.
4. **Tables.** `Scripts/generate_md_tables_corrected.R` writes Tables 1–4 into
   `cache/`; `Scripts/loo_compare_corrected.R` writes Table 5. The results are
   copied into `Tabs/`.
5. **Figures.** One script per figure, listed below. Each writes to `Plots/` at
   300 dpi and, where relevant, a CSV to `cache/`.
6. **Sensitivity checks.** Independent scripts, listed below; none of them feeds
   a table or figure.

## Fits

| Model | Specification | Script | Output |
| :--- | :--- | :--- | :--- |
| M1 v2 | Crossed random intercepts — the baseline used everywhere | `run_brms_m1_corrected_v2.R` | `rds/model_brms_m1_corrected_v2.rds` |
| M1 | Same, lower sampling settings (superseded by M1 v2) | `run_brms_m1_corrected.R` | `rds/model_brms_m1_corrected.rds` |
| M2 | Random slopes on Like Only | `run_brms_m2_corrected.R` | `rds/model_brms_m2_corrected.rds` |
| M3 | Random slopes on Listen Only and Like Only | `run_brms_m3_corrected.R` | `rds/model_brms_m3_corrected.rds` |
| M4 | Random slopes on Like Only and Both — preferred for Figs 4–6 | `run_brms_m4_corrected.R` | `rds/model_brms_m4_corrected.rds` |
| M5 | Full crossed random slopes | `run_brms_m5_corrected.R` | `rds/model_brms_m5_corrected.rds` |
| M6 | M5 plus education slopes in the genre random effects | `run_brms_m6_educslopes.R` | `rds/model_brms_m6_educslopes.rds` |
| M7 | M1 plus a centered quadratic arts term (tests the middling peak) | `run_brms_m7_artsquad.R` | `rds/model_brms_m7_artsquad.rds` |
| M8 | M4/M5 slopes plus a fixed arts-by-prestige interaction | `run_brms_m8_prestigeslopes.R` | `rds/model_brms_m8_prestigeslopes.rds` |

Slurm wrappers exist for M6–M8 (`Scripts/submit_*.sh`).

## Tables

| Table | File | Script | Fits read |
| :--- | :--- | :--- | :--- |
| 1 | `Tabs/table1_wald.md` | `generate_md_tables_corrected.R` | M1 v2 |
| 1b | `Tabs/table1b_wald_normality_check.md` | `generate_md_tables_corrected.R` | M1 v2 |
| 2 | `Tabs/table2_overclaim.md` | `generate_md_tables_corrected.R` | M1 v2 |
| 3 | `Tabs/table3_underclaim.md` | `generate_md_tables_corrected.R` | M1 v2 |
| 4 | `Tabs/table4_consistent.md` | `generate_md_tables_corrected.R` | M1 v2 |
| 5 | `Tabs/table5_fit.md`, `Tabs/table5_fit_raw.csv` | `loo_compare_corrected.R` | the five `rds/waic_m*_corrected*.rds` objects only (never the full fits) |

Both table scripts write to `cache/`; their output was copied to `Tabs/`. Table
5's `cache/` copies are not kept locally, so regenerate them with
`loo_compare_corrected.R` if needed.

## Figures

| Figure | File | Script | Inputs |
| :--- | :--- | :--- | :--- |
| 1 | `Plots/fig1_profiles.png` | `plot_purged_corrected.R` | M1 v2 fit; writes `cache/purged_genre_profiles_credsummary.csv` |
| 2 | `Plots/fig2_predicted_probs.png` | `plot_childarts_effects_corrected.R` | M1 v2 fit; writes `cache/childarts_predicted_probs.csv` |
| 3 | `Plots/fig3_capacity.png` | `plot_omnivorousness_corrected.R` | `dta/analysis_model_input.dta` only, no fit |
| 4 | `Plots/fig4_genre_odds.png` | `plot_odds_halfeye_corrected.R` | M4 fit; writes `cache/odds_overclaiming_by_genre.csv` |
| 5 | `Plots/fig5_intercept_vs_slope.png` | `plot_correlations_corrected.R` | M4 fit + `rds/ame_genre_constrained.rds`; writes `cache/genre_summary_correlations.csv`, `cache/correlation_point_estimates.csv` |
| 6 | `Plots/fig6_prestige_vs_odds.png` | `plot_correlations_corrected.R` | same as Figure 5; writes `cache/correlation_draws_summary.csv` |
| 7 | `Plots/fig7_educ_prestige_vs_odds.png` | `plot_educ_slopes_prestige.R` | `cache/m6_educ_genre_slopes.csv` only, rebuilds in seconds; companion to Figure 6, from the education-slopes fit |

Figures 5–7 plot posterior medians with 95% credible intervals and share the
same regression-line colour and styling.

`Scripts/submit_plot_correlations.sh` rebuilds Figures 5 and 6 on the cluster
(it loads the M4 fit once, about 15 seconds).

`rds/ame_genre_constrained.rds` is produced by `prep_ame_ratios_corrected.R`.
Its College Preference Ratio has mean 1.29 and range 0.72–2.04; the similarly
named `*_corrected` file on some machines is stale and must not be used.

## Sensitivity and robustness checks

| Check | Script | Output |
| :--- | :--- | :--- |
| Wider fixed-effect prior on M1 (`normal(0, 3)`) | `prior_sensitivity_model1.R` + `finish_prior_sensitivity_corrected.R` | `cache/prior_sensitivity_model1.csv` |
| Winamp cell dropped / collapsed | `robustness_platform.R` (+ `finish_robustness_platform.R`) | `cache/robustness_platform.csv` |
| LKJ prior on the genre intercept–slope correlation, LKJ(1) and LKJ(4) vs LKJ(2) | `sensitivity_lkj_prior.R` (+ `finish_sensitivity_lkj.R`) | `cache/sensitivity_lkj.csv` |
| Quadratic arts term (M7) | `run_brms_m7_artsquad.R` (or `finish_m7_artsquad.R` on the saved fit) | `cache/h2b_quadratic_arts.csv` |
| Education slopes vs prestige (M6) | `m6_educ_prestige_correlations.R` | `cache/m6_educ_prestige_correlations.csv`, `cache/m6_educ_genre_slopes.csv` |
| Is the Figure 7 correlation mechanical? (slopes vs a race-built ordering; listening vs liking gradient) | `m6_educ_slope_antitautology.R` | `cache/m6_educ_slope_antitautology_checks.csv` |
| Paired loo comparison of M6 against M5 | `compare_m6_m5_loo.R` | `cache/m6_vs_m5_loo_compare.csv` |
| Arts-by-prestige interaction (M8) | `run_brms_m8_prestigeslopes.R` | `cache/prestige_slope_test.csv` |
| WAIC recompute for a saved fit | `finish_waic_tag.R <tag>` | `rds/waic_<tag>.rds` |
| Fit diagnostics | `diagnose_m1v2_corrected.R`, `diagnose_mN_corrected.R` | `cache/diagnostics_m*.{md,txt}` |

## Conventions

Categorical predictors enter as factors, with `engagement_state` as a factor
with `refcat = "Neither"`, `race5` levels White/Black/Hispanic/Asian/Other-Mixed,
and `platform` levels Free Recall/Spotify/iTunes/Winamp/Other. Every fit script
guards this with `stopifnot(is.factor(...))`, because a missed `factor()` call
silently fits an ordinal race or platform slope.

Model objects stay local. `rds/*.rds` is gitignored along with the manuscript
folder, the codebooks, and `references.bib`.
