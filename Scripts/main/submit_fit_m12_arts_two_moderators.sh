#!/bin/bash
#SBATCH --job-name=m12_arts_mods
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m12_arts_mods_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=16

# Fits Model 12: Model 8 plus a second genre-level moderator, so the arts
# effect is allowed to vary with both the College Preference Ratio and genre
# popularity in the same likelihood. Default measure is the share of dyads in
# which the respondent listened to the genre; set POP_MEASURE in the R script
# to "liked" for the stated-liking variant (outputs are suffixed by measure).
# Output: rds/model_brms_m12_arts_mods_<measure>.rds,
#         rds/waic_m12_arts_mods_<measure>.rds,
#         cache/arts_prestige_popularity_test_<measure>.csv

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/fit_m12_arts_two_moderators.R
