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

#
module purge
#
module load gcc/10.1.0
module load openmpi/
module load netcdf-c/
module load netcdf-fortran/
module load hdf5/1.12.2
#
# from here, follow the instructions from:
# https://github.com/mom-ocean/MOM6/tree/main/ac
# pretty much exactly.
#
# Ideally, you'd have some "does this directory exist?" logic, but for brevity we'll exclude it (it will throw
#  some errors here and there, but move on).
#
if [[ ! -d MOM6-examples ]]; then
  git clone --recursive git@github.com:NOAA-GFDL/MOM6-examples.git
fi
#
echo "CD'd to `pwd`"
#
DO_FMS=1
DO_MOM6=1
DO_SIS2=1
#DO_SIS2_FMS=1
#
ROOT_PATH=`pwd`
MKMF_DIR="`pwd`/MOM6-examples/src/mkmf/bin"
MKFM_SHERLOCK_TEMPLATE="`pwd`/mkmf_templates/linux-gnu-sherlock-openmpi.mk"
MOM6_SRC="${ROOT_PATH}/MOM6-examples/src/MOM6"
MOM_VER="2016.9.17"
#
MOM6_OCEAN_EXE="MOM6-Ocean"
MOM6_SIS2_EXE="MOM6-SIS2"
#
BUILD_PATH_FMS="${ROOT_PATH}/MOM6-examples/build/fms_build"
BUILD_PATH_MOM6="${ROOT_PATH}/MOM6-examples/build/mom6_ocean_build"
BUILD_PATH_SIS2="${ROOT_PATH}/MOM6-examples/build/sis2_build"
BUILD_PATH_SIS2_FMS="${ROOT_PATH}/MOM6-examples/build/sis2_fms_build"
#
INSTALL_PREFIX="/home/groups/s-ees/share/cees/software/no_arch/MOM6/${MOM_VER}"
LINK_PATH_FMS="${INSTALL_PREFIX}/lib"
for dr in lib bin
do
  if [[ ! -d ${INSTALL_PREFIX}/$dr ]]; then
    mkdir -p ${INSTALL_PREFIX}/$dr
  fi
done
#
H5_PATH=$(dirname $(dirname $(which h5pcc)))
#
# TODO: ... or TOCONSIDER: copy all libraries to this path? Still (I think) need to use the build
#  directories to build components with dependencies, so we can use the .o, etc. objects. Or, just build
#  the whole thing all at once (ie, add FMS to the SIS2 setup.
SHARED_PATH="${ROOT_PATH}/MOM6-examples/shared"
if [[ ! -d ${SHARED_PATH} ]]; then
  mkdir -p ${SHARED_PATH}
fi
##############
#
if [[ $DO_FMS == 1 ]]; then
  # FMS:
  rm -rf ${BUILD_PATH_FMS}
  mkdir -p ${BUILD_PATH_FMS}
  cd ${BUILD_PATH_FMS}
  #
  echo "should be in FMS build path:"
  echo `pwd`
  #
  #rm -f path_names
  ${MKMF_DIR}/list_paths -l ${ROOT_PATH}/MOM6-examples/src/FMS
  ${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -p libfms.a -c "-Duse_libMPI -Duse_netCDF" path_names
  make NETCDF=3 REPRO=1 libfms.a -j
  #
  cp libfms.a ${INSTALL_PREFIX}/lib
fi
#
##########
# MOM6 (Ocean Only)
if [[ $DO_MOM6 == 1 ]]; then
  echo "*** *** Do MOM6 (Ocean Only) *** ***"
  echo "*** *** *** ***"
  rm -rf ${BUILD_PATH_MOM6}
  mkdir -p ${BUILD_PATH_MOM6}
  cd ${BUILD_PATH_MOM6}
  #
  echo "should be in MOM6 build path:"
  echo `pwd`
  #
  # TODO: Figure out how mkmf flags should be specified. I think the given syntax is wrong.
  rm -f path_names; \
  ${MKMF_DIR}/list_paths -l ${MOM6_SRC}/{config_src/infra/FMS1,config_src/memory/dynamic_symmetric,config_src/drivers/solo_driver,config_src/external,src/{*,*/*}}/
  #${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o '-I../shared/repro' -p MOM6 -l '-L../shared/repro -lfms' path_names
  #
  echo "MKMF COMMAND: "
  #CMD_MKF="${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o -I${BUILD_PATH_FMS} -p MOM6 -l (-L${BUILD_PATH_FMS} -lfms) path_names"
  CMD_MKF="${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o -I${BUILD_PATH_FMS} -p ${MOM6_OCEAN_EXE} path_names"
  #
  echo "CMD_MKF: $CMD_MKF"
  #${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -I '-I${BUILD_PATH_FMS}' -p MOM6 -l '-L${BUILD_PATH_FMS} -lfms' path_names
  $CMD_MKF
  #
  # LIBS_FROM_SHELL=" -L${BUILD_PATH_FMS} -lfms -L${H5_PATH}/lib -lhdf5 -lhdf5_hl -lhdf5_hl_fortran"
  LIBS_FROM_SHELL=" -L${BUILD_PATH_FMS} -lfms " make NETCDF=3 REPRO=1 ${MOM6_OCEAN_EXE} -j
  #
  cp ${MOM6_OCEAN_EXE} ${INSTALL_PREFIX}/bin
fi
###################
#
# SIS2 (MOM6 + coupled mode)
# MOM6 (Ocean Only)
if [[ $DO_SIS2 == 1 ]]; then
  echo "*** *** Do MOM6 (SIS2) *** ***"
  echo "*** *** *** ***"
  rm -rf ${BUILD_PATH_SIS2}
  mkdir -p ${BUILD_PATH_SIS2}
  cd ${BUILD_PATH_SIS2}
  rm -f path_names     # just in case we bypass nuking the build-dir, but want to refresh mkmf (eg, debug linking).
  #
  echo "should be in SIS2 build path:"
  echo `pwd`
  #
  # TODO: fix up these mkmf strings so they work, instead of just producing garbage.
  #
  echo "*** DEBUG [SIS2]: do MKMF/list_paths"
  ${MKMF_DIR}/list_paths -l\
   ${MOM6_SRC}/config_src/{infra/FMS1,memory/dynamic_symmetric,drivers/FMS_cap,external}\
   ${MOM6_SRC}/src/{*,*/*}/\
   ${ROOT_PATH}/MOM6-examples/src/{atmos_null,coupler,land_null,ice_param,icebergs,SIS2,FMS/coupler,FMS/include}/
  echo "*** DEBUG [SIS2]: list_paths complete."
  #
  #${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o '-I../shared' -p MOM6 -l '-L../shared/repro -lfms' -c '-Duse_AM3_physics -D_USE_LEGACY_LAND_' path_names
  ${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o -I${BUILD_PATH_FMS} -p ${MOM6_SIS2_EXE} -l'-L${LINK_PATH_FMS} -lfms' -c '-Duse_AM3_physics -D_USE_LEGACY_LAND_' path_names
  #${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o '-I${BUILD_PATH_FMS}' -p MOM6 -c '-Duse_AM3_physics -D_USE_LEGACY_LAND_' path_names
  #
  LIBS_FROM_SHELL=" -L${BUILD_PATH_FMS} -lfms " make NETCDF=3 REPRO=1 ${MOM6_SIS2_EXE} -j
  #
  cp ${MOM6_SIS2_EXE} ${INSTALL_PREFIX}/bin
fi

###################
#
# This should work (I think) by just adding all the FMS codes to the list_paths step,but it does not... or not yet, but since we don't need it,
#  we will forego the exercise for now.
#
## SIS2 (MOM6 + coupled mode) + FMS compiled in
## MOM6 (Ocean Only)
#if [[ $DO_SIS2_FMS == 1 ]]; then
#  echo "*** *** Do MOM6 (SIS2) + FMS *** ***"
#  echo "*** *** *** ***"
#  rm -rf ${BUILD_PATH_SIS2_FMS}
#  mkdir -p ${BUILD_PATH_SIS2_FMS}
#  cd ${BUILD_PATH_SIS2_FMS}
#  rm -f path_names     # just in case we bypass nuking the build-dir, but want to refresh mkmf (eg, debug linking).
#  #
#  echo "should be in SIS2 build path:"
#  echo `pwd`
#  #
#  echo "*** DEBUG [SIS2]: do MKMF/list_paths"
#  ${MKMF_DIR}/list_paths -l\
#   ${ROOT_PATH}/MOM6-examples/src/FMS\
#   ${MOM6_SRC}/config_src/{infra/FMS1,memory/dynamic_symmetric,drivers/FMS_cap,external}\
#   ${MOM6_SRC}/src/{*,*/*}/\
#   ${ROOT_PATH}/MOM6-examples/src/{atmos_null,coupler,land_null,ice_param,icebergs,SIS2,FMS/coupler,FMS/include}/
#  echo "*** DEBUG [SIS2]: list_paths complete."
#  #
#  #${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o '-I../shared' -p MOM6 -l '-L../shared/repro -lfms' -c '-Duse_AM3_physics -D_USE_LEGACY_LAND_' path_names
#  ${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o -I${BUILD_PATH_FMS} -p ${MOM6_SIS2_EXE}  -c '-Duse_AM3_physics -D_USE_LEGACY_LAND_' path_names
#  #${MKMF_DIR}/mkmf -t ${MKFM_SHERLOCK_TEMPLATE} -o '-I${BUILD_PATH_FMS}' -p MOM6 -c '-Duse_AM3_physics -D_USE_LEGACY_LAND_' path_names
#  #
#  echo "*** DEBUG: Now, do make"
#  make NETCDF=3 REPRO=1 ${MOM6_SIS2_EXE} -j
#fi
