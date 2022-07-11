#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors

. $CCTK_HOME/lib/make/bash_utils.sh

# Take care of requests to build the library in any case
ADIOS_DIR_INPUT=$ADIOS_DIR
if [ "$(echo "${ADIOS_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]; then
    ADIOS_BUILD=1
    ADIOS_DIR=
else
    ADIOS_BUILD=
fi

# default value for CUDA support
# TODO: hook up with ExternalLibraries/CUDA
if [ -z "$ADIOS_ENABLE_CUDA" ] ; then
    ADIOS_ENABLE_CUDA="no"
fi

# default value for FORTRAN support
if [ -z "$ADIOS_ENABLE_FORTRAN" ] ; then
    ADIOS_ENABLE_FORTRAN="no"
fi

# default value for SST support
if [ -z "$ADIOS_ENABLE_SST" ] ; then
    ADIOS_ENABLE_SST="no"
fi

################################################################################
# Decide which libraries to link with
################################################################################

# Set up names of the libraries based on configuration variables. Also
# assign default values to variables.
# Try to find the library if build isn't explicitly requested
if [ -z "${ADIOS_BUILD}" -a -z "${ADIOS_INC_DIRS}" -a -z "${ADIOS_LIB_DIRS}" -a -z "${ADIOS_LIBS}" ]; then
    find_lib ADIOS adios 1 1.0 adios2_core "adios2.h" "$ADIOS_DIR"
fi

THORN=ADIOS

# configure library if build was requested or is needed (no usable
# library found)
if [ -n "$ADIOS_BUILD" -o -z "${ADIOS_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "Using bundled ADIOS..."
    echo "END MESSAGE"
    ADIOS_BUILD=1

    check_tools "tar patch"
    
    # Set locations
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${ADIOS_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing ADIOS into ${ADIOS_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${ADIOS_INSTALL_DIR}
    fi
    ADIOS_DIR=${INSTALL_DIR}
    # Fortran modules may be located in the lib directory
    ADIOS_INC_DIRS="${ADIOS_DIR}/include ${ADIOS_DIR}/lib"
    ADIOS_LIB_DIRS="${ADIOS_DIR}/lib"
    ADIOS_LIBS="adios2_cxx11 adios2_c adios2_core adios2_taustubs"
    if [ "$(echo ${ADIOS_ENBABLE_FORTRAN} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
      ADIOS_LIBS="adios2_fortran ${ADIOS_LIBS}"
    fi
    if [ -n "${MPI_DIR+set}" ]; then
        ADIOS_LIBS="adios2_cxx11_mpi adios2_c_mpi adios2_core_mpi ${ADIOS_LIBS}"
        if [ "$(echo ${ADIOS_ENBABLE_FORTRAN} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
          ADIOS_LIBS="adios2_fortran_mpi ${ADIOS_LIBS}"
        fi
    fi
else
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    if [ ! -e ${DONE_FILE} ]; then
        mkdir ${SCRATCH_BUILD}/done 2> /dev/null || true
        date > ${DONE_FILE}
    fi
fi

if [ -n "$ADIOS_DIR" ]; then
    : ${ADIOS_RAW_LIB_DIRS:="$ADIOS_LIB_DIRS"}
    # Fortran modules may be located in the lib directory
    ADIOS_INC_DIRS="$ADIOS_RAW_LIB_DIRS $ADIOS_INC_DIRS"
    # We need the un-scrubbed inc dirs to look for a header file below.
    : ${ADIOS_RAW_INC_DIRS:="$ADIOS_INC_DIRS"}
else
    echo 'BEGIN ERROR'
    echo 'ERROR in ADIOS configuration: Could neither find nor build library.'
    echo 'END ERROR'
    exit 1
fi

################################################################################
# Check for additional libraries
################################################################################


################################################################################
# Configure Cactus
################################################################################

# Pass configuration options to build script
echo "BEGIN MAKE_DEFINITION"
echo "ADIOS_BUILD          = ${ADIOS_BUILD}"
echo "ADIOS_ENABLE_FORTRAN = ${ADIOS_ENABLE_FORTRAN}"
echo "ADIOS_ENABLE_SST     = ${ADIOS_ENABLE_SST}"
echo "LIBSZ_DIR           = ${LIBSZ_DIR}"
echo "LIBZ_DIR            = ${LIBZ_DIR}"
echo "ADIOS_INSTALL_DIR    = ${ADIOS_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "ADIOS_DIR            = ${ADIOS_DIR}"
echo "ADIOS_ENABLE_FORTRAN = ${ADIOS_ENABLE_FORTRAN}"
echo "ADIOS_INC_DIRS       = ${ADIOS_INC_DIRS} ${ZLIB_INC_DIRS}"
echo "ADIOS_LIB_DIRS       = ${ADIOS_LIB_DIRS} ${ZLIB_LIB_DIRS}"
echo "ADIOS_LIBS           = ${ADIOS_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(ADIOS_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(ADIOS_LIB_DIRS)'
echo 'LIBRARY           $(ADIOS_LIBS)'
