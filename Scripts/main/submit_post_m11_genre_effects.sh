#!/bin/bash
#SBATCH --job-name=m11_genre_effects
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=02:00:00
#SBATCH --output=m11_genre_effects_job.log

# Exports every genre-level quantity Figures 5-10 need from Model 11 (paper
# Model 3): arts and education slope draws, per-genre summaries and odds ratios,
# draw-level correlations, and the Figure 8 intercept/slope pairs.

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m11_genre_effects.R
