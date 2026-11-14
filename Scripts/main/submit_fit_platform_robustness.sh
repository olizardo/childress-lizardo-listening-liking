#!/bin/bash
#SBATCH --job-name=robustness_platform
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=robustness_platform_job.log
#SBATCH --time=08:00:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=16

# Fits two robustness variants of the baseline intercepts model (dropping
# Winamp; collapsing Winamp into Other) and compares child_arts coefficients
# against the original Model 1 fit. Variant (a) is already on disk from the
# 2026-11-13 run and is reused via brm(file_refit = "on_change"); only variant
# (b) needs to be sampled again. What caused the 2026-11-13 OOM was the
# comparison step holding two variant fits plus the baseline in 3 GB, so
# memory is raised to 48 GB (matching the M1-M5 fits) and the script now
# extracts and drops each fit one at a time.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/robustness_platform.R
