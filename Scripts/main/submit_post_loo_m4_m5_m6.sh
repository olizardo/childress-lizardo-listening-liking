#!/bin/bash
#SBATCH --job-name=loo_m4_m5_m6
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --output=loo_m4_m5_m6_job.log
#SBATCH --time=20:00:00
#SBATCH --mem=48G
#SBATCH --cpus-per-task=4

# PSIS-LOO for M4, M5 and M6 (no refitting), recomputing the ranking that the
# WAIC table reports. Three separate loo calls, each loading its own fit; the
# first M5 loo took over 2.5 hours, so the 3-hour limit used by the earlier
# comparison job is not enough for three models. Existing rds/loo_*.rds objects
# are reused, so a timeout resumes where it stopped.

module load intel/2026.2.0
module load R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5

export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_loo_m4_m5_m6.R
