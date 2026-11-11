#!/bin/bash
# Slurm submission for the corrected Model 1 and Model 4 refits.
# Hoffman2 (OARC cluster): submit with `sbatch Scripts/submit_corrected.sh`
# from the project root. Runs the two fits sequentially in one job.
# Old-cluster Grid Engine wrappers (submit_brms_*.sh) are superseded.

#SBATCH --job-name=brms_corrected
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/brms_corrected_%j.out
#SBATCH --error=logs/brms_corrected_%j.err

set -euo pipefail

# Resolve the project directory from where sbatch was invoked
PROJECT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$PROJECT_DIR"
mkdir -p logs rds

module load R 2>/dev/null || echo "NOTE: no R module found; relying on PATH R"

export SLURM_CPUS_PER_TASK
export CMDSTANR_NO_VER_CHECK=TRUE

echo "=== Starting Model 1 (corrected) ==="
Rscript --no-save --no-restore Scripts/run_brms_m1_corrected.R

echo "=== Starting Model 4 (corrected) ==="
Rscript --no-save --no-restore Scripts/run_brms_m4_corrected.R

echo "=== Both fits complete ==="
