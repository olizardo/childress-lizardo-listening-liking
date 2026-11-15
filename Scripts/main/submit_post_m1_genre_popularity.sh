#!/bin/bash
#SBATCH --job-name=m1_genre_pop
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=02:00:00
#SBATCH --output=m1_genre_pop_job.log

# Model-based genre popularity from the random-intercepts baseline: one minus the
# fitted Neither probability per genre, averaged over that genre's rows, 1,000
# draws. Loads one fit.

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m1_genre_popularity.R
