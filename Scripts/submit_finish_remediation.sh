#!/bin/bash
#$ -cwd
#$ -j y
#$ -o finish_remediation_job.log
#$ -l h_rt=4:00:00
#$ -l h_data=6G
#$ -pe shared 8

# CRITICAL: Must initialize the module system first in non-interactive Grid Engine shells
source /u/local/Modules/default/init/bash

module load gcc/10.2.0
module load R

export cmdstanr_no_ver_check=TRUE

mkdir -p cache rds

# Each of these is a SEPARATE Rscript process, so the multi-hundred-MB to
# multi-GB in-memory footprint of a loaded brmsfit is fully released when
# each subprocess exits, rather than accumulating across steps.
echo "=== Step 1/5: refit convergence diagnostics ==="
Rscript Scripts/check_convergence_refits.R

echo "=== Step 2/5: LKJ prior sensitivity comparison ==="
Rscript Scripts/finish_sensitivity_lkj.R

echo "=== Step 3/5: platform robustness comparison ==="
Rscript Scripts/finish_robustness_platform.R

echo "=== Step 4/5: Model 1 prior sensitivity comparison ==="
Rscript Scripts/finish_prior_sensitivity_model1.R

echo "=== Step 5/5: final paired WAIC model comparison ==="
Rscript Scripts/finish_loo_compare.R

echo "=== All remediation finishing steps complete ==="
