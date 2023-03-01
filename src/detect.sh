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
ADIOS2_DIR_INPUT=$ADIOS2_DIR
if [ "$(echo "${ADIOS2_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]; then
    ADIOS2_BUILD=1
    ADIOS2_DIR=
else
    ADIOS2_BUILD=
fi

# default value for CUDA support
# TODO: hook up with ExternalLibraries/CUDA
if [ -z "$ADIOS2_ENABLE_CUDA" ] ; then
    ADIOS2_ENABLE_CUDA="no"
fi

# default value for FORTRAN support
if [ -z "$ADIOS2_ENABLE_FORTRAN" ] ; then
    ADIOS2_ENABLE_FORTRAN="no"
fi

# default value for SST support
if [ -z "$ADIOS2_ENABLE_SST" ] ; then
    ADIOS2_ENABLE_SST="no"
fi

################################################################################
# Decide which libraries to link with
################################################################################

# Set up names of the libraries based on configuration variables. Also
# assign default values to variables.
# Try to find the library if build isn't explicitly requested
if [ -z "${ADIOS2_BUILD}" -a -z "${ADIOS2_INC_DIRS}" -a -z "${ADIOS2_LIB_DIRS}" -a -z "${ADIOS2_LIBS}" ]; then
    find_lib ADIOS2 adios 1 1.0 adios2_core "adios2.h" "$ADIOS2_DIR"
fi

THORN=ADIOS2

# configure library if build was requested or is needed (no usable
# library found)
if [ -n "$ADIOS2_BUILD" -o -z "${ADIOS2_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "Using bundled ADIOS2..."
    echo "END MESSAGE"
    ADIOS2_BUILD=1

    check_tools "tar patch"
    
    # Set locations
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${ADIOS2_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing ADIOS2 into ${ADIOS2_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${ADIOS2_INSTALL_DIR}
    fi
    ADIOS2_DIR=${INSTALL_DIR}
    # Fortran modules may be located in the lib directory
    ADIOS2_INC_DIRS="${ADIOS2_DIR}/include ${ADIOS2_DIR}/lib"
    ADIOS2_LIB_DIRS="${ADIOS2_DIR}/lib"
    ADIOS2_LIBS="adios2_cxx11 adios2_c adios2_core"
    if [ "$(echo ${ADIOS2_ENBABLE_FORTRAN} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
      ADIOS2_LIBS="adios2_fortran ${ADIOS2_LIBS}"
    fi
    if [ -n "${MPI_DIR+set}" ]; then
        ADIOS2_LIBS="adios2_cxx11_mpi adios2_c_mpi adios2_core_mpi ${ADIOS2_LIBS}"
        if [ "$(echo ${ADIOS2_ENBABLE_FORTRAN} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
          ADIOS2_LIBS="adios2_fortran_mpi ${ADIOS2_LIBS}"
        fi
    fi
else
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    if [ ! -e ${DONE_FILE} ]; then
        mkdir ${SCRATCH_BUILD}/done 2> /dev/null || true
        date > ${DONE_FILE}
    fi
fi

if [ -n "$ADIOS2_DIR" ]; then
    : ${ADIOS2_RAW_LIB_DIRS:="$ADIOS2_LIB_DIRS"}
    # Fortran modules may be located in the lib directory
    ADIOS2_INC_DIRS="$ADIOS2_RAW_LIB_DIRS $ADIOS2_INC_DIRS"
    # We need the un-scrubbed inc dirs to look for a header file below.
    : ${ADIOS2_RAW_INC_DIRS:="$ADIOS2_INC_DIRS"}
else
    echo 'BEGIN ERROR'
    echo 'ERROR in ADIOS2 configuration: Could neither find nor build library.'
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
echo "ADIOS2_BUILD          = ${ADIOS2_BUILD}"
echo "ADIOS2_ENABLE_FORTRAN = ${ADIOS2_ENABLE_FORTRAN}"
echo "ADIOS2_ENABLE_SST     = ${ADIOS2_ENABLE_SST}"
echo "LIBSZ_DIR           = ${LIBSZ_DIR}"
echo "LIBZ_DIR            = ${LIBZ_DIR}"
echo "ADIOS2_INSTALL_DIR    = ${ADIOS2_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "ADIOS2_DIR            = ${ADIOS2_DIR}"
echo "ADIOS2_ENABLE_FORTRAN = ${ADIOS2_ENABLE_FORTRAN}"
echo "ADIOS2_INC_DIRS       = ${ADIOS2_INC_DIRS} ${ZLIB_INC_DIRS}"
echo "ADIOS2_LIB_DIRS       = ${ADIOS2_LIB_DIRS} ${ZLIB_LIB_DIRS}"
echo "ADIOS2_LIBS           = ${ADIOS2_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(ADIOS2_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(ADIOS2_LIB_DIRS)'
echo 'LIBRARY           $(ADIOS2_LIBS)'
