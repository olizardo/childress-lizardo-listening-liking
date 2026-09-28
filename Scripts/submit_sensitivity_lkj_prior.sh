#!/bin/bash
#$ -cwd
#$ -j y
#$ -o sensitivity_lkj_prior_job.log
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

# Refits Model 5 under lkj(1) and lkj(4) priors and compares the genre-level
# LikeOnly intercept-slope correlation against the original lkj(2) fit.
Rscript Scripts/sensitivity_lkj_prior.R
