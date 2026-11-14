#!/bin/bash
#SBATCH --job-name=m7_artsquad
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=m7_artsquad_job.log
#SBATCH --time=23:50:00
#SBATCH --mem=6G
#SBATCH --cpus-per-task=16

# Fits Model 7: corrected Model 1 plus a centered quadratic term in
# childhood arts exposure, as a direct test of H2B (overclaiming peaking at
# middling cultural capital). Output: rds/model_brms_m7_artsquad.rds +
# rds/waic_m7_artsquad.rds + cache/diagnostics_m7.txt

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export CMDSTANR_CORES=$SLURM_CPUS_PER_TASK
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/run_brms_m7_artsquad.R
