#!/bin/bash
# Grid Engine job: build R 4.5.3 into $HOME/Rlocal/4.5.3 on the legacy
# IDRE cluster, so the Model 17 fit can run there (its brms/cmdstanr
# library was built under R 4.5.1/4.6.1 and cannot load under R 4.2.2).
#
# Submit from the home directory:
#   qsub -N r_build -l h_rt=04:00:00 -l mem_free=8G -cwd -j y -o r_build.log build_r453_ge.sh

#$ -N r_build
#$ -l h_rt=04:00:00
#$ -l mem_free=8G
#$ -cwd
#$ -j y
#$ -o r_build.log

module load gcc/10.2.0
export LD_LIBRARY_PATH=/u/local/compilers/gcc/10.2.0/lib64:$LD_LIBRARY_PATH

set -x
cd $HOME

if [ ! -f R-4.5.3.tar.gz ]; then
  wget -q https://cran.r-project.org/src/base/R-4/R-4.5.3.tar.gz
fi
rm -rf R-4.5.3
tar xf R-4.5.3.tar.gz
cd R-4.5.3

./configure --prefix=$HOME/Rlocal/4.5.3 --with-x=no \
  --with-blas --with-lapack > r_configure.log 2>&1 || {
  cat r_configure.log; exit 1; }

make -j8 > r_make.log 2>&1 || { tail -40 r_make.log; exit 1; }
make install > r_install.log 2>&1 || { tail -40 r_install.log; exit 1; }

$HOME/Rlocal/4.5.3/bin/Rscript --version
echo "BUILD OK"
