#!/bin/bash
#SBATCH --job-name=m6_arts_slopes
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=01:00:00
#SBATCH --output=m6_arts_slopes_job.log

# Exports Model 6 arts-exposure slopes by equation for Figure 11.

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m6_arts_slopes_by_state.R
