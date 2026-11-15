#!/bin/bash
#SBATCH --job-name=m17_race_post
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=02:00:00
#SBATCH --output=m17_race_post_job.log

# Summarises the two race-specific genre slopes in Model 17: the fixed
# coefficient, the random-slope SD and its correlation with the genre
# intercept, and each genre's total slope. Loads one 48 GB fit.

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m17_race_slopes.R
