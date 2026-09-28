#!/bin/bash
#$ -cwd
#$ -j y
#$ -o regenerate_figures_job.log
#$ -l h_rt=2:00:00
#$ -l h_data=8G
#$ -pe shared 4

source /u/local/Modules/default/init/bash
module load gcc/10.2.0
module load R

export cmdstanr_no_ver_check=TRUE

mkdir -p Plots cache

echo "=== Ensuring required packages are installed ==="
Rscript -e "
  options(repos = c(CRAN = 'https://cloud.r-project.org'))
  pkgs <- c('ggrepel', 'tidybayes', 'ggdist', 'tibble', 'tidyr', 'haven', 'posterior', 'dplyr', 'ggplot2', 'brms')
  for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
"

# Each script is its own Rscript process so the ~600MB-on-disk / multi-GB
# in-memory Model 4 refit is fully released between plots.
echo "=== 1/5: purged genre engagement profiles (Figure 1) ==="
Rscript Scripts/plot_purged_random_intercepts.R

echo "=== 2/5: omnivorousness capacity divergence plot ==="
Rscript Scripts/plot_omnivorousness_capacity.R

echo "=== 3/5: odds-of-overclaiming half-eye plot ==="
Rscript Scripts/plot_odds_overclaiming_halfeye.R

echo "=== 4/5: intercept-slope & prestige correlation plots + draw-wise correlation stats ==="
Rscript Scripts/plot_correlations.R

echo "=== 5/5: per-state random intercept half-eye plots (supplementary) ==="
Rscript Scripts/plot_random_intercepts_halfeye.R

echo "=== All figures regenerated from Model 4 (preferred specification) ==="
