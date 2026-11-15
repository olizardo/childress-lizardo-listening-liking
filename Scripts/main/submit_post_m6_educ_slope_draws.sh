#!/bin/bash
#SBATCH --job-name=educ_draws
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=educ_draws_job.log
#SBATCH --time=02:00:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=4

# Exports Model 6 genre education slope draws for Figure 6 (no refitting).

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m6_educ_slope_draws.R
