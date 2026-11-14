#!/bin/bash
#SBATCH --job-name=plot_corr
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=plot_corr_job.log
#SBATCH --time=01:30:00
#SBATCH --mem=40G
#SBATCH --cpus-per-task=4

# Rebuilds Figures 6 and 7 from the saved Model 4 fit (no refitting). Loads one
# brmsfit for draw extraction, so 40 GB covers it.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/figure_6_7_correlations.R
