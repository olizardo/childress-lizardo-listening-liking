#!/bin/bash
#SBATCH --job-name=compare_m6_m5
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=compare_m6_m5_job.log
#SBATCH --time=03:00:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=4

# Paired loo comparison of M6 against M5 (no refitting). 48 GB matches the
# M1-M5 fits, which needed that much for the pointwise log-likelihood matrix.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/compare_m6_m5_loo.R
