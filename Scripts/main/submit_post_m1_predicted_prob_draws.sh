#!/bin/bash
#SBATCH --job-name=m1_pred_prob_draws
#SBATCH --account=pi_olizardo
#SBATCH --qos=campus24
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=01:00:00
#SBATCH --output=m1_pred_prob_draws_job.log

# Exports the 1,000 posterior draws of predicted engagement-state probabilities
# at each arts level 1-7 (Model 1), for the posterior-distribution companion to
# Figure 3. posterior_epred needs ~1 GB arrays per level, which froze the 14 GB
# local machine.

module load intel/2026.2.0 R/4.6.1
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

Rscript Scripts/main/post_m1_predicted_prob_draws.R
