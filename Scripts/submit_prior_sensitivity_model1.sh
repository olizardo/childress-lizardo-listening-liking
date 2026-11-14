#!/bin/bash
#SBATCH --job-name=prior_sensitivity_model1
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=prior_sensitivity_model1_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=3G
#SBATCH --cpus-per-task=16

# Refits Model 1 with a wider fixed-effect prior and compares child_arts
# coefficients against the original normal(0, 1.5) specification.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/prior_sensitivity_model1.R
