# Overclaiming in Musical Tastes: Replication Package

This repository contains the data and code needed to reproduce all tables and
figures in the paper. Manuscript materials, fitted model objects, and working
files are kept locally and are not part of this repository.

## Contents

- `dta/` — analysis datasets (`analysis_time_CCC.dta`, `analysis_time_long.dta`,
  `analysis_time_R_processed.dta`, `genresobjects.dta`)
- `Scripts/` — data preparation (`analysis_time.R`, `clean_artistgenre.R`),
  model fits (`run_brms_*.R`, `submit_brms_*.sh`), diagnostics and model
  comparison (`check_convergence*.R`, `finish_loo_compare.R`),
  sensitivity/robustness checks, and figure scripts (`plot_*.R`)
- `do/` — Stata versions of the data-preparation pipeline
- `cache/` — markdown tables and CSV summaries feeding the manuscript tables
- `Plots/` — manuscript figures
- `renv.lock` + `renv/` — locked R package environment

## Reproducing the results

1. Restore the environment: `renv::restore()`
2. Fit the models with `Scripts/submit_brms_*.sh` (CmdStan 2.33.1 via
   `cmdstanr`; refits use `iter = 4000, warmup = 1500, adapt_delta = 0.97`)
3. Regenerate tables with `Scripts/generate_md_tables.R` and
   `Scripts/finish_loo_compare.R`
4. Regenerate figures with the `Scripts/plot_*.R` scripts
