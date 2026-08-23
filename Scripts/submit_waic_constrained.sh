#!/bin/bash
#$ -cwd
#$ -j y
#$ -o waic_constrained_job.log
#$ -l h_rt=04:00:00
#$ -l h_data=4G
#$ -pe shared 4

# Initialize module system
source /u/local/Modules/default/init/bash

# Load modern compiler and R
module load gcc/10.2.0
module load R

export CMDSTANR_CORES=$NSLOTS
export cmdstanr_no_ver_check=TRUE

# Run WAIC computation
Rscript Scripts/compute_waic_constrained.R
