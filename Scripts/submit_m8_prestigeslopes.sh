#!/bin/bash
#SBATCH --job-name=m8_prestigeslopes
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m8_prestigeslopes_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=16

# Fits Model 8: Model 4/M5 crossed random slopes plus child_arts * prestige_c
# as a fixed effect, which makes the H3A-versus-H3B contrast a single
# coefficient. Output: rds/model_brms_m8_prestigeslopes.rds +
# rds/waic_m8_prestigeslopes.rds + cache/diagnostics_m8.txt +
# cache/prestige_slope_test.csv

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/run_brms_m8_prestigeslopes.R
