#!/bin/bash
#SBATCH --job-name=finish_waic_m6
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=finish_waic_m6_job.log
#SBATCH --time=08:00:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=4

# Recomputes WAIC for the saved m6_educslopes fit (no refitting). The original job
# requested only 6 GB and was OOM-killed at this step; the M1-M5 fits all
# requested 48 GB for the same post-processing.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/finish_waic_tag.R m6_educslopes
