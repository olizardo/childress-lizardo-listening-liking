#!/bin/bash
#SBATCH --job-name=m6_educ_checks
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m6_educ_checks_job.log
#SBATCH --time=02:00:00
#SBATCH --mem=24G
#SBATCH --cpus-per-task=4

# Post-processing only: genre-level correlations between the Model 6 education
# slopes and educational prestige (no refitting).

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/check_education_prestige_correlation.R
