#!/bin/bash
#SBATCH --job-name=m17_race_slopes
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m17_race_slopes_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=16

# Fits Model 17: Model 1 (baseline) plus a genre random slope on the Black
# dummy in the overclaiming equation and on the Hispanic dummy in the
# underclaiming equation. Output:
# rds/model_brms_m17_race_slopes.rds + rds/waic_m17_race_slopes.rds

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/fit_m17_race_slopes.R
