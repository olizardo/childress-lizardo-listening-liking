#!/bin/bash
#SBATCH --job-name=finish_waic_m7
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=finish_waic_m7_job.log
#SBATCH --time=08:00:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=4

# Recomputes WAIC for the saved m7_artsquad fit and rebuilds
# cache/h2b_quadratic_arts.csv (both are written after the point where the
# 1630710 job was OOM-killed). Requested 6 GB originally; 48 GB matches the
# M1-M5 fits.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m7_arts_quadratic.R
