#!/bin/bash
#SBATCH --job-name=prev_marg
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --mem=48G
#SBATCH --time=02:00:00
#SBATCH --output=prev_marg_job.log

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

Rscript Scripts/main/check_state_prevalences.R
