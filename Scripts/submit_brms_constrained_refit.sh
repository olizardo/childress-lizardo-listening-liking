#!/bin/bash
#$ -cwd
#$ -j y
#$ -o brms_constrained_refit_job.log
#$ -l h_rt=23:50:00
#$ -l h_data=4G
#$ -pe shared 16

# CRITICAL: Must initialize the module system first in non-interactive Grid Engine shells
source /u/local/Modules/default/init/bash

# Must load modern GCC before R
module load gcc/10.2.0
module load R

# Pass allocated cores to R
export CMDSTANR_CORES=$NSLOTS
export cmdstanr_no_ver_check=TRUE

# Run brms Constrained LikeOnly Slopes REFIT model (iter=4000, warmup=1500, adapt_delta=0.97)
Rscript Scripts/run_brms_constrained_refit.R
