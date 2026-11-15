#!/bin/bash
#SBATCH --job-name=m9_draws
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=01:00:00
#SBATCH --output=m9_draws_job.log

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

Rscript Scripts/main/post_m9_prestige_draws.R
