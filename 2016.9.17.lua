-- -*- lua -*-
--
depends_on("system", "math")

depends_on("gcc/10.1.0")
depends_on("openmpi/")
depends_on("netcdf-c/")
depends_on("netcdf-fortran")
depends_on("hdf5/1.12.2")
--
whatis("Name: GFDL MOM6 Ocean simulator, build from gcc/10.1.0 + openmpi/4.1.2 (?) . Should includ and Ocean-only as well as MOM6+SIS2 coupled model.")
--
VER=myModuleVersion()
MOM6_PREFIX=pathJoin("/home/groups/s-ees/share/cees/software/no_arch/MOM6/", VER)
BIN_DIR=pathJoin(MOM6_PREFIX, "bin")
LIB_DIR=pathJoin(MOM6_PREFIX, "lib")
--
pushenv("MOM6_DIR", MOM6_PREFIX)
pushenv("MOM6_BIN", BIN_DIR)
--
prepend_path("PATH", BIN_DIR)
prepend_path("LD_LIBRARY_PATH", LIB_DIR)
