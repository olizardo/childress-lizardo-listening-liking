#!/bin/bash
#SBATCH --job-name=m11_educarts_liking
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m11_educarts_liking_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=16

# Fits Model 11: Model 4's structure with education-by-genre slopes added on the
# overclaiming and consistent-engagement equations, so the arts and education
# slopes share one restricted structure (80 random slopes, none in the
# underclaiming equation). Output:
# rds/model_brms_m11_educarts_liking.rds + rds/waic_m11_educarts_liking.rds

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/fit_m11_education_arts_liking_slopes.R
