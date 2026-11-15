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
- `Scripts/` — one script per step, named `<stage>_<what it does>.R`:
  - `Scripts/main/` — everything that reproduces a table or figure in the
    paper, plus the sensitivity and robustness checks the text cites, and their
    `submit_*.sh` Slurm wrappers.
  - `Scripts/supporting/` — fits M2 and M3 (Table 5 comparison rows only) and
    the diagnostics helpers. Not needed for any other output.
  - `Scripts/legacy/` — superseded fits, duplicate post-processing scripts, the
    residualized-intercept analysis removed from the paper, and the
    doc-shuffling Python tooling. Kept for the record, not part of the pipeline.

  Stage prefixes: `prep_` builds data or derived measures, `fit_mN_` is one
  model fit, `fit_` is a sensitivity or robustness refit, `post_` processes a
  saved fit, `make_` writes manuscript tables, `figure_N_` writes a figure,
  `check_` is a secondary analysis supporting prose or a footnote, and
  `submit_<stem>.sh` is the cluster wrapper for the R script of the same stem.
  Scripts resolve paths from the repository root, so run them from there
  (`Rscript Scripts/main/fit_m4_slopes_like_both.R`).
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

1. **Genres.** `Scripts/main/prep_artist_genre.R` rebuilds the artist-to-genre codes
   and writes `dta/genresobjects_processed.dta`. It needs `dta/genresobjects.dta`
   and `csv/to inc.csv` (the hand-coded inclusion list), which is **not** in the
   repository; restore it before rerunning this step. Its output is already in
   `dta/`, so every later step runs without it.
2. **Model input.** `Scripts/main/prep_model_input.R` splices the rebuilt
   `genre_final1-10` and `stream_source` columns into the respondent file and
   writes `dta/analysis_model_input.dta`. The `genre_final*` columns inside
   `analysis_time_CCC.dta` are shuffled across respondents and are always
   overwritten here; never read them from that file.
3. **Fits.** One script per specification; each writes its fit and a WAIC object
   to `rds/`.
4. **Tables.** `Scripts/main/make_tables.R` writes Tables 1–4 into
   `cache/`; `Scripts/main/make_table5_fit_comparison.R` writes Table 5. The results are
   copied into `Tabs/`.
5. **Figures.** One script per figure, listed below. Each writes to `Plots/` at
   300 dpi and, where relevant, a CSV to `cache/`.
6. **Sensitivity checks.** Independent scripts, listed below; none of them feeds
   a table or figure.

## Fits

| Model | Specification | Script | Output |
| :--- | :--- | :--- | :--- |
| M1 v2 | Crossed random intercepts — the baseline used everywhere | `Scripts/main/fit_m1_baseline.R` | `rds/model_brms_m1_corrected_v2.rds` |
| M1 | Same, lower sampling settings (superseded by M1 v2) | `Scripts/legacy/fit_m1_v1.R` | `rds/model_brms_m1_corrected.rds` |
| M2 | Random slopes on Like Only | `Scripts/supporting/fit_m2_arts_on_likeonly.R` | `rds/model_brms_m2_corrected.rds` |
| M3 | Random slopes on Listen Only and Like Only | `Scripts/supporting/fit_m3_arts_on_listen_like.R` | `rds/model_brms_m3_corrected.rds` |
| M4 | Random slopes on Like Only and Both — preferred for Figs 4–6 | `Scripts/main/fit_m4_slopes_like_both.R` | `rds/model_brms_m4_corrected.rds` |
| M5 | Full crossed random slopes | `Scripts/main/fit_m5_full_slopes.R` | `rds/model_brms_m5_corrected.rds` |
| M6 | M5 plus education slopes in the genre random effects | `Scripts/main/fit_m6_education_slopes.R` | `rds/model_brms_m6_educslopes.rds` |
| M7 | M1 plus a centered quadratic arts term (tests the middling peak) | `Scripts/main/fit_m7_arts_quadratic.R` | `rds/model_brms_m7_artsquad.rds` |
| M8 | M4/M5 slopes plus a fixed arts-by-prestige interaction | `Scripts/main/fit_m8_arts_by_prestige.R` | `rds/model_brms_m8_prestigeslopes.rds` |
| M9 | M6 plus a fixed education-by-prestige interaction (Figure 10 as a model test) | `Scripts/main/fit_m9_education_by_prestige.R` | `rds/model_brms_m9_educprestige.rds` |

Slurm wrappers sit beside their R scripts (`Scripts/main/submit_<stem>.sh`).

## Tables

| Table | File | Script | Fits read |
| :--- | :--- | :--- | :--- |
| 1 | `Tabs/table1_wald.md` | `Scripts/main/make_tables.R` | M1 v2 |
| 1b | `Tabs/table1b_wald_normality_check.md` | `Scripts/main/make_tables.R` | M1 v2 |
| 2 | `Tabs/table2_overclaim.md` | `Scripts/main/make_tables.R` | M1 v2 |
| 3 | `Tabs/table3_underclaim.md` | `Scripts/main/make_tables.R` | M1 v2 |
| 4 | `Tabs/table4_consistent.md` | `Scripts/main/make_tables.R` | M1 v2 |
| 5 | `Tabs/table5_fit.md`, `Tabs/table5_fit_raw.csv` (full ladder), `Tabs/table5_fit_reduced.md`, `Tabs/table5_fit_reduced.csv` (the doc's six rows) | `Scripts/main/make_table5_fit_comparison.R`, `Scripts/main/make_table5_reduced.R` | the `rds/waic_m*.rds` objects only (never the full fits) |

Both table scripts write to `cache/`; their output was copied to `Tabs/`. Every
fitted model now has a local `rds/waic_m*.rds`, so the full fifteen-row ladder
rebuilds without the cluster.

## Figures

| Figure | File | Script | Inputs |
| :--- | :--- | :--- | :--- |
| 1 | `Plots/fig1_state_prevalences.png` | `Scripts/main/figure_1_state_prevalences.R` | `cache/state_prevalences_marginal_m1.csv` only, no fit; rebuilt by `Scripts/main/check_state_prevalences.R` |
| 2 | `Plots/fig2_profiles.png` | `Scripts/main/figure_2_profiles.R` | M1 v2 fit; writes `cache/purged_genre_profiles_credsummary.csv` |
| 3 | `Plots/fig3_predicted_probs.png` | `Scripts/main/figure_3_predicted_probs.R` | M1 v2 fit; writes `cache/childarts_predicted_probs.csv` |
| 4 | `Plots/fig4_capacity.png` | `Scripts/main/figure_4_capacity.R` | `dta/analysis_model_input.dta` only, no fit; writes `cache/capacity_by_arts.csv` (per-level `n`, means for liked and listened genres) |
| 5 | `Plots/fig5_genre_odds_both.png` | `Scripts/main/figure_5_genre_odds_both_exposures.R` | `cache/m11_arts_slope_draws.csv` and `cache/m11_educ_slope_draws.csv`, rebuilds in seconds; writes `cache/odds_overclaiming_by_genre.csv` and `cache/odds_education_by_genre.csv`. One two-panel figure, each panel ordered by its own effect sizes. Paper Model 3 = M11 |
| 6 | `Plots/fig6_popularity_vs_slopes.png` | `Scripts/main/figure_6_popularity_vs_slopes.R` | `cache/m1_genre_popularity_draws.csv` (baseline fit) and the M11 slope draws; writes `cache/popularity_slope_correlations.csv` and `cache/popularity_slope_points.csv`. Two panels, arts and education slopes against popularity |
| 7 | `Plots/fig7_prestige_odds.png` | `Scripts/main/figure_7_prestige_odds.R` | `cache/m11_genre_summary.csv` and `cache/m11_correlations.csv`; two panels, arts and education odds against the College Preference Ratio, log odds ratio scale |
| 8 | `Plots/fig8_arts_by_prestige.png` | `Scripts/main/figure_8_arts_by_prestige.R` | `cache/m14_moderator_draws.csv` (arts draws) and `cache/m6_arts_slope_by_state.csv`, rebuilds in seconds; arts interaction curve across the College Preference Ratio for the three states, from paper Model 6 (M14) |
| 9 | `Plots/fig9_education_by_prestige.png` | `Scripts/main/figure_9_education_by_prestige.R` | `cache/m14_moderator_draws.csv` (education draws) and `cache/m6_educ_slope_by_state.csv`, rebuilds in seconds; education interaction curve, companion to Figure 8 |

The doc holds nine figures since 2026-11-15, when three pairs were merged two
panels to a figure, and the local file numbers now match the paper's. The five
single-panel scripts behind the merged pairs are archived in `Scripts/legacy/`
and no longer feed the manuscript: `figure_5_genre_odds.R` and
`figure_6_education_genre_odds.R` (now the two panels of Figure 5),
`figure_7_9_correlations.R` and `figure_8_intercept_vs_education_slope.R`
(the intercept-versus-slope plots, dropped from the paper), and
`figure_10_education_slopes.R` (now the right panel of Figure 7). Their PNGs
were deleted from `Plots/`; they can be rebuilt from the archived scripts. The
Figure 3b posterior-draws companion (`figure_3b_posterior_draws.R`, reading
`cache/childarts_predicted_probs_draws.csv.gz`) is archived there as well.

Figures 5–9 plot posterior medians with 95% credible intervals, and Figures 5–7
share the same regression-line colour and styling. Figures 8 and 9 carry a bold
boxed coefficient-and-p-value inset, with draws from
`Scripts/main/post_m14_moderator_draws.R` (`submit_post_m14_moderator_draws.sh`)
and free-slope points from `Scripts/main/post_m6_arts_slopes_by_state.R`
(`submit_post_m6_arts_slopes_by_state.sh`) and the existing education by-state file.

`Scripts/legacy/submit_figure_7_9_correlations.sh` belongs to the archived
intercept-versus-slope figures and no longer builds anything in the paper.

`rds/ame_genre_constrained.rds` is produced by `Scripts/main/prep_genre_preference_ratios.R`.
Its College Preference Ratio has mean 1.29 and range 0.72–2.04; the similarly
named `*_corrected` file on some machines is stale and must not be used.

## Sensitivity and robustness checks

| Check | Script | Output |
| :--- | :--- | :--- |
| Wider fixed-effect prior on M1 (`normal(0, 3)`) | `Scripts/main/fit_prior_sensitivity.R` + `Scripts/main/post_prior_sensitivity.R` | `cache/prior_sensitivity_model1.csv` |
| Winamp cell dropped / collapsed | `Scripts/main/fit_platform_robustness.R` (+ `Scripts/main/post_platform_robustness.R`) | `cache/robustness_platform.csv` |
| LKJ prior on the genre intercept–slope correlation, LKJ(1) and LKJ(4) vs LKJ(2) | `Scripts/main/fit_lkj_sensitivity.R` (+ `Scripts/main/post_lkj_sensitivity.R`) | `cache/sensitivity_lkj.csv` |
| Quadratic arts term (M7) | `Scripts/main/fit_m7_arts_quadratic.R` (or `Scripts/main/post_m7_arts_quadratic.R` on the saved fit) | `cache/h2b_quadratic_arts.csv` |
| Education slopes vs prestige (M6) | `Scripts/main/check_education_prestige_correlation.R` | `cache/m6_educ_prestige_correlations.csv`, `cache/m6_educ_genre_slopes.csv` |
| Is the Figure 10 correlation mechanical? (slopes vs a race-built ordering; listening vs liking gradient) | `Scripts/main/check_education_slope_antitautology.R` | `cache/m6_educ_slope_antitautology_checks.csv` |
| Education × genre prestige interaction as a model-level test of the Figure 10 gradient (M9) | `Scripts/main/fit_m9_education_by_prestige.R` | `cache/educ_prestige_test.csv` |
| Covariate-averaged prevalence of the four engagement states | `Scripts/main/check_state_prevalences.R` | `cache/state_prevalences_marginal_m1.csv` |
| Paired loo comparison of M6 against M5 | `Scripts/main/post_m6_vs_m5_loo.R` | `cache/m6_vs_m5_loo_compare.csv` |
| PSIS-LOO for the three models whose ranking matters (M4, M5, M6), plus Pareto-k diagnostics | `Scripts/main/post_loo_m4_m5_m6.R` (+ `Scripts/main/submit_post_loo_m4_m5_m6.sh`) | `rds/loo_m{4,5,6}*.rds`, `cache/loo_m4_m5_m6_compare.csv`, `cache/loo_pareto_k_summary.csv` |
| Arts-by-prestige interaction (M8) | `Scripts/main/fit_m8_arts_by_prestige.R` | `cache/prestige_slope_test.csv` |
| WAIC recompute for a saved fit | `Scripts/main/post_waic.R <tag>` | `rds/waic_<tag>.rds` |
| Fit diagnostics | `Scripts/supporting/diagnose_m1_v2.R`, `Scripts/supporting/diagnose_fit.R` | `cache/diagnostics_m*.{md,txt}` |

## Conventions

Categorical predictors enter as factors, with `engagement_state` as a factor
with `refcat = "Neither"`, `race5` levels White/Black/Hispanic/Asian/Other-Mixed,
and `platform` levels Free Recall/Spotify/iTunes/Winamp/Other. Every fit script
guards this with `stopifnot(is.factor(...))`, because a missed `factor()` call
silently fits an ordinal race or platform slope.

Model objects stay local. `rds/*.rds` is gitignored along with the manuscript
folder, the codebooks, and `references.bib`.
