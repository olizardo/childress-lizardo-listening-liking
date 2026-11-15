#!/bin/bash
# Grid Engine wrapper for the legacy IDRE cluster (hoffman2.idre.ucla.edu).
#
# PREREQUISITE: the legacy cluster's newest R is 4.2.2 and the existing
# library (~/R/x86_64-pc-linux-gnu-library/4.5) was built under R 4.5.1+,
# so it does not load (Rcpp: undefined symbol R_getVarEx). A local R 4.5+
# must be built first, e.g.:
#   qsub -N r_build -l h_rt=04:00:00 -l mem_free=8G -cwd \
#     -b y "wget https://cran.r-project.org/src/base/R-4/R-4.5.3.tar.gz && \
#           tar xf R-4.5.3.tar.gz && cd R-4.5.3 && \
#           ./configure --prefix=$HOME/Rlocal/4.5.3 --with-x=no && make -j8 && make install"
# Then point R_HOME below at $HOME/Rlocal/4.5.3 and reinstall the packages
# into $HOME/R/x86_64-pc-linux-gnu-library/4.5 with that R.
#
# Submit from the repo root on the legacy cluster:
#   qsub -N m17_race_slopes -l h_rt=24:00:00 -l mem_free=48G \
#        -pe shared 16 -cwd Scripts/main/submit_fit_m17_race_slopes_ge.sh
#
# NOTE: cmdstan-2.33.1 already exists at ~/.cmdstan/cmdstan-2.33.1 on the
# legacy cluster. Output lands in rds/model_brms_m17_race_slopes.rds and
# rds/waic_m17_race_slopes.rds; the log is m17_race_slopes.o<jobid>.

#$ -N m17_race_slopes
#$ -l h_rt=24:00:00
#$ -l mem_free=48G
#$ -pe shared 16
#$ -cwd
#$ -j y
#$ -o m17_race_slopes_job.log

# Local R built under the prerequisite step; adjust if the prefix differs.
export R_HOME=$HOME/Rlocal/4.5.3
export PATH=$R_HOME/bin:$PATH
export R_LIBS_USER=$HOME/R/x86_64-pc-linux-gnu-library/4.5
export cmdstanr_no_ver_check=TRUE

# Newer libstdc++ for Rcpp built with gcc 10 (module is default gcc/7.5.0).
module load gcc/10.2.0
export LD_LIBRARY_PATH=/u/local/compilers/gcc/10.2.0/lib64:$LD_LIBRARY_PATH

echo "R: $(R --version | head -1)"
echo "brms: $(Rscript -e 'cat(as.character(packageVersion("brms")))' 2>/dev/null)"

Rscript Scripts/main/fit_m17_race_slopes.R
