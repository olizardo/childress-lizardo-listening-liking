#!/bin/bash
#SBATCH --job-name=m18_both_quad
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m18_both_quad_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=16

# Fits Model 18: corrected Model 1 plus centered quadratic terms for childhood
# arts exposure and educational attainment in all three equations. Same priors
# and sampling settings as Model 7, so the paired WAIC difference isolates the
# two curvature terms. Output: rds/model_brms_m18_both_curvature.rds +
# rds/waic_m18_both_curvature.rds + cache/diagnostics_m18.txt +
# cache/m18_curvature.csv

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/fit_m18_both_curvature.R
