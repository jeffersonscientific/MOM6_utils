#!/bin/bash
#
#SBATCH --job-name=compile_mom6
#SBATCH --partition=serc
#SBATCH --cpus-per-task=8
#SBATCH --time=12:00:00
#SBATCH --output=mom6_compile.out
#SBATCH --error=mom6_compiler.err
#
# see instructions at:
# https://github.com/mom-ocean/MOM6/tree/main/ac
#
#
# load CEES-beta stack:
. /home/groups/s-ees/share/cees/spack_cees/scripts/cees_sw_setup-beta.sh
#
module purge
#
#module load gcc-cees-beta/
#module load mpich-cees-beta/
#module load netcdf-c-cees-beta/
#module load netcdf-fortran-cees-beta/
#
# this stack appears to work as well:
module load gcc/10.1
module load openmpi/
module load netcdf-c/
module load netcdf-fortran/
#
# from here, follow the instructions from:
# https://github.com/mom-ocean/MOM6/tree/main/ac
# pretty much exactly.
#
# Ideally, you'd have some "does this directory exist?" logic, but for brevity we'll exclude it (it will throw
#  some errors here and there, but move on).
#
if [[ ! -d MOM6 ]]; then
  git clone --recursive git@github.com:mom-ocean/MOM6.git
fi
cd MOM6
#
# this is your main working dir; stick it into a variable:
MOM_DIR=`pwd`
#
# funny story... it is possibel I had to run this twice for it to work. It should do quite a bit of work if it's working.
cd ac/deps
make -j
make -j
#
cd ../..          # Return to the root directory
cd ac
autoreconf
#
cd ..             # Return to the root directory
rm -rf build
mkdir -p build
cd build
../ac/configure
make -j

