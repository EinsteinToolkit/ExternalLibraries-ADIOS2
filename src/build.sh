#! /bin/bash

################################################################################
# Build
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors



# Set locations
THORN=ADIOS2
NAME=ADIOS2-2.10.2
SRCDIR="$(dirname $0)"
BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
if [ -z "${ADIOS2_INSTALL_DIR}" ]; then
    INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
else
    echo "BEGIN MESSAGE"
    echo "Installing ADIOS2 into ${ADIOS2_INSTALL_DIR}"
    echo "END MESSAGE"
    INSTALL_DIR=${ADIOS2_INSTALL_DIR}
fi
DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
ADIOS2_DIR=${INSTALL_DIR}

echo "ADIOS2: Preparing directory structure..."
cd ${SCRATCH_BUILD}
mkdir build external done 2> /dev/null || true
rm -rf ${BUILD_DIR} ${INSTALL_DIR}
mkdir ${BUILD_DIR} ${INSTALL_DIR}

# Build core library
echo "ADIOS2: Unpacking archive..."
pushd ${BUILD_DIR}
${TAR?} xf ${SRCDIR}/../dist/${NAME}.tar

cd ${NAME}

echo "ADIOS2: Applying patches..."
${PATCH?} -p1 < ${SRCDIR}/../dist/stdint.patch
${PATCH?} -p1 < ${SRCDIR}/../dist/ent-no-docs.patch
# Some (ancient but still used) versions of patch don't support the
# patch format used here but also don't report an error using the exit
# code. So we use this patch to test for this
${PATCH?} -p1 < ${SRCDIR}/../dist/patchtest.patch
if [ ! -e .patch_tmp ]; then
    echo 'BEGIN ERROR'
    echo 'The version of patch is too old to understand this patch format.'
    echo 'Please set the PATCH environment variable to a more recent '
    echo 'version of the patch command.'
    echo 'END ERROR'
    exit 1
fi
rm -f .patch_tmp

echo "ADIOS2: Configuring..."

if [ "${CCTK_DEBUG_MODE}" = yes ]; then
    ADIOS2_BUILD_TYPE=Debug
else
    ADIOS2_BUILD_TYPE=Release
fi

# TODO: might be useful to build non-MPI version all the time so that it can
# run on login nodes
if [ -n "${HAVE_CAPABILITY_MPI}" ]; then
    ADIOS2_USE_MPI=ON
else
    ADIOS2_USE_MPI=OFF
fi

# workaround for https://github.com/ornladios/ADIOS2/issues/3148
# "Static build, BP5 on SST off fails"
ADIOS2_USE_BP5="${ADIOS2_ENABLE_SST}"

# TODO: merge with option list options
# if [ -n "${HAVE_CAPABILITY_CUDA}" ]; then
#     ADIOS2_USE_CUDA=ON
# else
#     ADIOS2_USE_CUDAS=OFF
# fi

# CMake's FindMPI does not reliably locate an MPI installation built from
# source by the MPI thorn (no system MPI is registered), which causes
# find_package(MPI) to fail with e.g. "Could NOT find MPI_CXX (missing:
# MPI_CXX_LIB_NAMES MPI_CXX_HEADER_DIR MPI_CXX_WORKS)". When the MPI thorn
# built MPI from source (MPI_BUILD set), hint CMake at it via MPI_HOME and
# the wrapper compilers found beneath MPI_DIR.
#
# For a system or manually configured MPI (MPI_BUILD empty) FindMPI instead
# interrogates whatever wrapper compiler it finds, and some wrappers defeat
# it: Intel oneAPI's mpicc answers none of the -showme / -compile-info style
# queries FindMPI issues (only -show, which FindMPI does not use), so
# MPI_<LANG>_LIB_NAMES stays empty and FindMPI's link test fails with
# "undefined symbol: MPI_Init" even though mpi.h was found via MPI_HOME.
# The MPI thorn has already resolved MPI_INC_DIRS / MPI_LIB_DIRS / MPI_LIBS
# for exactly this configuration, so skip wrapper interrogation altogether
# and pass those to FindMPI as its manual MPI_<LANG>_HEADER_DIR,
# MPI_<LANG>_LIB_NAMES and MPI_<lib>_LIBRARY settings (C and C++ only;
# Fortran keeps CMake's own detection). Only libraries found beneath
# MPI_LIB_DIRS are listed: FindMPI demands a resolved path for every name
# and does not fall back to the system paths, and the remaining entries of
# MPI_LIBS (typically rt, pthread, dl) are system libraries the final Cactus
# link adds from MPI_LIBS anyway.
MPI_C_OPTION=
MPI_CXX_OPTION=
MPI_Fortran_OPTION=
MPI_MANUAL_OPTIONS=
if [ -n "${MPI_BUILD}" ] && [ -n "${MPI_DIR}" ] && [ -d "${MPI_DIR}" ]; then
  export MPI_HOME="${MPI_DIR}"
  if [ -x "${MPI_DIR}/bin/mpicc" ]; then
    MPI_C_OPTION="-DMPI_C_COMPILER=${MPI_DIR}/bin/mpicc"
  fi
  if [ -x "${MPI_DIR}/bin/mpicxx" ]; then
    MPI_CXX_OPTION="-DMPI_CXX_COMPILER=${MPI_DIR}/bin/mpicxx"
  fi
  if [ "${ADIOS2_ENABLE_FORTRAN}" = ON ] && [ -x "${MPI_DIR}/bin/mpifort" ]; then
    MPI_Fortran_OPTION="-DMPI_Fortran_COMPILER=${MPI_DIR}/bin/mpifort"
  fi
  export PATH="${MPI_DIR}/bin:${PATH}"
elif [ -n "${MPI_INC_DIRS}" ] && [ -n "${MPI_LIBS}" ]; then
  MPI_FIRST_INC_DIR="${MPI_INC_DIRS%% *}"
  MPI_EXTRA_INC_DIRS=$(echo ${MPI_INC_DIRS#"${MPI_FIRST_INC_DIR}"} | tr ' ' ';')
  MPI_MANUAL_OPTIONS="-DMPI_C_HEADER_DIR=${MPI_FIRST_INC_DIR} -DMPI_CXX_HEADER_DIR=${MPI_FIRST_INC_DIR}"
  if [ -n "${MPI_EXTRA_INC_DIRS}" ]; then
    MPI_MANUAL_OPTIONS="${MPI_MANUAL_OPTIONS} -DMPI_C_ADDITIONAL_INCLUDE_DIRS=${MPI_EXTRA_INC_DIRS} -DMPI_CXX_ADDITIONAL_INCLUDE_DIRS=${MPI_EXTRA_INC_DIRS}"
  fi
  MPI_LIB_NAMES=
  for MPI_LIB in ${MPI_LIBS}; do
    for MPI_LIB_DIR in ${MPI_LIB_DIRS}; do
      for MPI_LIB_FILE in "${MPI_LIB_DIR}/lib${MPI_LIB}.so" "${MPI_LIB_DIR}/lib${MPI_LIB}.a"; do
        if [ -f "${MPI_LIB_FILE}" ]; then
          MPI_LIB_NAMES="${MPI_LIB_NAMES}${MPI_LIB_NAMES:+;}${MPI_LIB}"
          MPI_MANUAL_OPTIONS="${MPI_MANUAL_OPTIONS} -DMPI_${MPI_LIB}_LIBRARY=${MPI_LIB_FILE}"
          break 2
        fi
      done
    done
  done
  MPI_MANUAL_OPTIONS="${MPI_MANUAL_OPTIONS} -DMPI_C_LIB_NAMES=${MPI_LIB_NAMES} -DMPI_CXX_LIB_NAMES=${MPI_LIB_NAMES}"
fi

# ADIOS2_INSTALL_GENERATE_CONFIG=OFF: at install time ADIOS2 otherwise
# generates an adios2-config shell script by configuring a dummy CMake
# project in a fresh process, whose find_package(adios2) re-runs FindMPI
# without any of the settings above and fails the same way. Nothing in
# Cactus uses adios2-config (this thorn and openPMD consume the CMake
# package files, and neither declares any utilities), so skip generating it.
#
# Should adios2-config ever be needed: ADIOS2's generator
# (cmake/install/post/generate-adios2-config.sh.in) appends the environment
# variable EXTRA_CMAKE_ARGS to the dummy project's cmake command line, so
# exporting the manual settings in it before ${MAKE} install, i.e.
#   export EXTRA_CMAKE_ARGS="${MPI_MANUAL_OPTIONS}"
# lets the install-time FindMPI succeed as well and the script can be
# generated again. Untested here: the generator then compiles and links
# small test programs with the Cactus compilers and parses verbose make
# output for flags, which is more surface for a GPU toolchain to trip on.
mkdir build
cd build
${CMAKE_DIR:+${CMAKE_DIR}/bin/}cmake -DADIOS2_USE_MPI=${ADIOS2_USE_MPI} -DADIOS2_INSTALL_GENERATE_CONFIG=OFF ${MPI_C_OPTION} ${MPI_CXX_OPTION} ${MPI_Fortran_OPTION} ${MPI_MANUAL_OPTIONS} -DADIOS2_USE_HDF5=OFF -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_INSTALL_LIBDIR=lib  -DBUILD_TESTING=OFF -DADIOS2_BUILD_EXAMPLES=OFF -DADIOS2_USE_Campaign=OFF -DADIOS2_USE_Fortran=${ADIOS2_ENABLE_FORTRAN} -DADIOS2_USE_Python=OFF -DADIOS2_USE_ZeroMQ=OFF -DADIOS2_USE_PNG=OFF -DADIOS2_USE_BZip2=OFF -DADIOS2_USE_SST=${ADIOS2_ENABLE_SST} -DADIOS2_USE_BP5=${ADIOS2_USE_BP5} -DADIOS2_USE_CUDA=${ADIOS2_ENABLE_CUDA} -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=${ADIOS2_BUILD_TYPE} ..

echo "ADIOS2: Building..."
${MAKE}

echo "ADIOS2: Installing..."
${MAKE} install
popd

echo "ADIOS2: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "ADIOS2: Done."
