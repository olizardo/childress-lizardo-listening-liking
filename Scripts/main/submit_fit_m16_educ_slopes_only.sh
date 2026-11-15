#!/bin/bash
#SBATCH --job-name=m16_educ_only
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=20:00:00
#SBATCH --exclude=n7444
#SBATCH --output=m16_educ_only_job.log

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

Rscript Scripts/main/fit_m16_educ_slopes_only.R
