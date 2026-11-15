#!/bin/bash
#SBATCH --job-name=m14_draws
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=01:00:00
#SBATCH --output=m14_draws_job.log

# Exports Model 14 moderator draws for Figures 11 (arts) and 12 (education).

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m14_moderator_draws.R
