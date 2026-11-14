#!/bin/bash
#SBATCH --job-name=finish_prior_sens
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=finish_prior_sens_job.log
#SBATCH --time=02:00:00
#SBATCH --mem=40G
#SBATCH --cpus-per-task=4

# Post-hoc comparison of the child_arts coefficients across the normal(0, 1.5)
# and normal(0, 3) priors. Both fits are already saved; the original job
# requested 3 GB and was OOM-killed when it loaded the baseline fit alongside
# the wide-prior one. This script loads one fit at a time.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_prior_sensitivity.R
