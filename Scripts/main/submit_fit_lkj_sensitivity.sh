#!/bin/bash
#SBATCH --job-name=sensitivity_lkj_prior
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=sensitivity_lkj_prior_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=16

# Refits Model 5 under lkj(1) and lkj(4) priors and compares the genre-level
# LikeOnly intercept-slope correlation against the original lkj(2) fit.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/fit_lkj_sensitivity.R
