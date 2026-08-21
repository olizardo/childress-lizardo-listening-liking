#!/bin/bash
#$ -cwd
#$ -j y
#$ -o mblogit_intercepts_job.log
#$ -l h_rt=23:50:00
#$ -l h_data=16G
#$ -pe shared 4

source /u/local/Modules/default/init/bash
module load gcc/10.2.0
module load R

Rscript Scripts/run_mblogit_intercepts.R
