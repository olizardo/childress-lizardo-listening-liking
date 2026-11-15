#!/bin/bash
#SBATCH --job-name=both_mods_extract
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=40G
#SBATCH --time=01:00:00
#SBATCH --exclude=n7444
#SBATCH --output=both_mods_extract_job.log

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

Rscript Scripts/main/post_both_moderators_extract.R "$@"
