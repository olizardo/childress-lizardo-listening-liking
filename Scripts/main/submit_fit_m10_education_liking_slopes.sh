#!/bin/bash
#SBATCH --job-name=m10_educslopes_liking
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m10_educslopes_liking_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=16

# Fits Model 10: Model 6 with the education-by-genre slopes restricted to the
# overclaiming and consistent-engagement equations, while the arts slopes stay
# in all three. Nested within Model 6, so the paired WAIC comparison isolates
# what the education slopes in the underclaiming equation buy. Output:
# rds/model_brms_m10_educslopes_liking.rds + rds/waic_m10_educslopes_liking.rds

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/fit_m10_education_liking_slopes.R
