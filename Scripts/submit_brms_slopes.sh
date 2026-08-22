#!/bin/bash
#$ -cwd
#$ -j y
#$ -o brms_slopes_job.log
#$ -l h_rt=23:50:00
#$ -l h_data=3G
#$ -pe shared 16

# CRITICAL: Must initialize the module system first in non-interactive Grid Engine shells
source /u/local/Modules/default/init/bash

# Must load modern GCC before R
module load gcc/10.2.0
module load R

# Pass allocated cores to R
export CMDSTANR_CORES=$NSLOTS
export cmdstanr_no_ver_check=TRUE

# Stagger concurrent tasks by 15 mins if running array jobs
if [ ! -z "$SGE_TASK_ID" ] && [ "$SGE_TASK_ID" -eq 2 ]; then
  sleep 900
fi

# Ensure CmdStan backend is compiled natively with modern toolchain
Rscript -e "
  options(repos = c(CRAN = 'https://cloud.r-project.org'))
  if (!requireNamespace('brms', quietly = TRUE)) install.packages('brms')
  if (!requireNamespace('cmdstanr', quietly = TRUE)) install.packages('cmdstanr', repos = c('https://mc-stan.org/r-packages/', getOption('repos')))
  if (!requireNamespace('haven', quietly = TRUE)) install.packages('haven')
  if (!requireNamespace('dplyr', quietly = TRUE)) install.packages('dplyr')
  if (!requireNamespace('tidyr', quietly = TRUE)) install.packages('tidyr')

  library(cmdstanr)
  cmdstanr::set_cmdstan_path('~/.cmdstan/cmdstan-2.33.1')

  if (as.integer(Sys.getenv('SGE_TASK_ID', 1)) == 1 && !dir.exists(file.path(Sys.getenv('HOME'), '.cmdstan/cmdstan-2.33.1'))) {
    cmdstanr::install_cmdstan(version = '2.33.1', cores = Sys.getenv('NSLOTS', unset = 4), overwrite = TRUE)
  }
"

# Run brms Random Slopes model
Rscript Scripts/run_brms_slopes.R
