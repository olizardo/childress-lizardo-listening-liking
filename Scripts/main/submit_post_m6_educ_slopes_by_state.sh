#!/bin/bash
#SBATCH --job-name=m6_educ_states
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=01:00:00
#SBATCH --output=m6_educ_states_job.log

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

Rscript Scripts/main/post_m6_educ_slopes_by_state.R
