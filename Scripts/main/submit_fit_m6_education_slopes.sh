#!/bin/bash
#SBATCH --job-name=m6_educslopes
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m6_educslopes_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=6G
#SBATCH --cpus-per-task=16

# Fits Model 6: M5 specification with educ2 added to the genre random
# effects (1 + child_arts + educ2 | genre_id), for the second
# capital-indicator check on H3A/B. Output:
# rds/model_brms_m6_educslopes.rds + rds/waic_m6_educslopes.rds

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/run_brms_m6_educslopes.R
