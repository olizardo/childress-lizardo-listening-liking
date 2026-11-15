#!/bin/bash
#SBATCH --job-name=m14_both_restr
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=08:00:00
#SBATCH --output=m14_both_restr_job.log

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

Rscript Scripts/main/fit_m14_both_mods_restricted.R
