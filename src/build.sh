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
THORN=ADIOS
NAME=ADIOS2-2.8.1
SRCDIR="$(dirname $0)"
BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
if [ -z "${ADIOS_INSTALL_DIR}" ]; then
    INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
else
    echo "BEGIN MESSAGE"
    echo "Installing ADIOS into ${ADIOS_INSTALL_DIR}"
    echo "END MESSAGE"
    INSTALL_DIR=${ADIOS_INSTALL_DIR}
fi
DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
ADIOS_DIR=${INSTALL_DIR}

echo "ADIOS: Preparing directory structure..."
cd ${SCRATCH_BUILD}
mkdir build external done 2> /dev/null || true
rm -rf ${BUILD_DIR} ${INSTALL_DIR}
mkdir ${BUILD_DIR} ${INSTALL_DIR}

# Build core library
echo "ADIOS: Unpacking archive..."
pushd ${BUILD_DIR}
${TAR?} xf ${SRCDIR}/../dist/${NAME}.tar

echo "ADIOS: Applying patches..."
pushd ${NAME}
${PATCH?} -p1 < ${SRCDIR}/../dist/hdf5_version.patch
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
popd

echo "ADIOS: Configuring..."
cd ${NAME}

if [ "${CCTK_DEBUG_MODE}" = yes ]; then
    ADIOS_BUILD_TYPE=Debug
else
    ADIOS_BUILD_TYPE=Release
fi

# TODO: might be useful to build non-MPI version all the time so that it can
# run on login nodes
if [ -n "${HAVE_CAPABILITY_MPI}" ]; then
    ADIOS2_USE_MPI=ON
else
    ADIOS2_USE_MPI=OFF
fi

if [ -n "${HAVE_CAPABILITY_HDF5}" ]; then
    ADIOS_HDF5_OPTS="-DHDF5_ROOT=${HDF5_DIR} -DADIOS2_USE_HDF5=ON"
else
    ADIOS_HDF5_OPTS="-DADIOS2_USE_HDF5=OFF"
fi

mkdir build
cd build
${CMAKE_DIR:+${CMAKE_DIR}/bin/}cmake -DADIOS2_USE_MPI=${ADIOS2_USE_MPI} ${ADIOS_HDF5_OPTS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_INSTALL_LIBDIR=lib  -DBUILD_TESTING=OFF -DADIOS2_BUILD_EXAMPLES=OFF -DADIOS2_USE_Fortran=${ADIOS_ENABLE_FORTRAN} -DADIOS2_USE_Python=OFF -DADIOS2_USE_ZeroMQ=OFF -DADIOS2_USE_PNG=OFF -DADIOS2_USE_BZip2=OFF -DADIOS2_USE_SST=${ADIOS_ENABLE_SST} -DADIOS2_USE_CUDA=${ADIOS_ENABLE_CUDA} -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=${ADIOS_BUILD_TYPE} ..

echo "ADIOS: Building..."
${MAKE}

echo "ADIOS: Installing..."
${MAKE} install
popd

echo "ADIOS: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "ADIOS: Done."
