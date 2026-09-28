#!/bin/bash
#$ -cwd
#$ -j y
#$ -o prior_sensitivity_model1_job.log
#$ -l h_rt=23:50:00
#$ -l h_data=3G
#$ -pe shared 16

# CRITICAL: Must initialize the module system first in non-interactive Grid Engine shells
source /u/local/Modules/default/init/bash

# Must load modern GCC before R
module load gcc/10.2.0
module load R

export CMDSTANR_CORES=$NSLOTS
export cmdstanr_no_ver_check=TRUE

# Refits Model 1 with a wider fixed-effect prior and compares child_arts
# coefficients against the original normal(0, 1.5) specification.
Rscript Scripts/prior_sensitivity_model1.R
