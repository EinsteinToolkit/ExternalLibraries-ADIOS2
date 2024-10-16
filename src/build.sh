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
NAME=ADIOS2-2.10.1
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

echo "ADIOS2: Configuring..."
cd ${NAME}

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

mkdir build
cd build
${CMAKE_DIR:+${CMAKE_DIR}/bin/}cmake -DADIOS2_USE_MPI=${ADIOS2_USE_MPI} -DADIOS2_USE_HDF5=OFF -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_INSTALL_LIBDIR=lib  -DBUILD_TESTING=OFF -DADIOS2_BUILD_EXAMPLES=OFF -DADIOS2_USE_Campaign=OFF -DADIOS2_USE_Fortran=${ADIOS2_ENABLE_FORTRAN} -DADIOS2_USE_Python=OFF -DADIOS2_USE_ZeroMQ=OFF -DADIOS2_USE_PNG=OFF -DADIOS2_USE_BZip2=OFF -DADIOS2_USE_SST=${ADIOS2_ENABLE_SST} -DADIOS2_USE_BP5=${ADIOS2_USE_BP5} -DADIOS2_USE_CUDA=${ADIOS2_ENABLE_CUDA} -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=${ADIOS2_BUILD_TYPE} ..

echo "ADIOS2: Building..."
${MAKE}

echo "ADIOS2: Installing..."
${MAKE} install
popd

echo "ADIOS2: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "ADIOS2: Done."
