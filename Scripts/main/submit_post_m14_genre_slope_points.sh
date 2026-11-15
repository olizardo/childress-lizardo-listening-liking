#!/bin/bash
#SBATCH --job-name=m14_slope_points
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=02:00:00
#SBATCH --output=m14_slope_points_job.log

# Exports the twenty free genre arts and education slopes for the two liking
# equations of Model 14, so Figures 11 and 12 draw both their interaction
# curves and their per-genre points from the same fit.

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m14_genre_slope_points.R
