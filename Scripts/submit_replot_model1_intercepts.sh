#!/bin/bash
#$ -cwd
#$ -j y
#$ -o replot_model1_intercepts_job.log
#$ -l h_rt=1:00:00
#$ -l h_data=8G
#$ -pe shared 4

source /u/local/Modules/default/init/bash
module load gcc/10.2.0
module load R

export cmdstanr_no_ver_check=TRUE
mkdir -p Plots cache

Rscript Scripts/plot_purged_random_intercepts.R
Rscript Scripts/plot_random_intercepts_halfeye.R
