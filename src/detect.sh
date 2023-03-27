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

ADIOS2_REQ_LIBS="adios2_cxx11 adios2_c adios2_core"
if [ "${ADIOS2_ENABLE_FORTRAN}" = 'yes' ]; then
    ADIOS2_REQ_LIBS="adios2_fortran $ADIOS2_REQ_LIBS"
fi

# Set up names of the libraries based on configuration variables. Also
# assign default values to variables.
# Try to find the library if build isn't explicitly requested
if [ -z "${ADIOS2_BUILD}" -a -z "${ADIOS2_INC_DIRS}" -a -z "${ADIOS2_LIB_DIRS}" -a -z "${ADIOS2_LIBS}" ]; then
    find_lib ADIOS2 adios 1 1.0 "$ADIOS2_REQ_LIBS" "adios2.h" "$ADIOS2_DIR"

    # any libraries needed b/c of ADIOS compile options
    ADIOS2CONFFILES="adios2/common/ADIOSConfig.h"
    for dir in $ADIOS2_INC_DIRS; do
        for file in $ADIOS2CONFFILES ; do
            if [ -r "$dir/$file" ]; then
                ADIOS2CONF="$ADIOS2CONF $dir/$file"
                break
            fi
        done
    done
    if [ -z "$ADIOS2CONF" ]; then
        echo 'BEGIN MESSAGE'
        echo 'WARNING in ADIOS2 configuration: '
        echo "None of $ADIOS2CONFFILES found in $ADIOS2_INC_DIRS"
        echo "Automatic detection of MPI use not possible"
        echo 'END MESSAGE'
    else
      # Check whether we have to link with MPI
      if grep -qe '^#define ADIOS2_HAVE_MPI' "$ADIOS2CONF" 2> /dev/null; then
          test_mpi=0
      else
          test_mpi=1
      fi
      if [ $test_mpi -eq 0 ]; then
          mpi_libs="" # need to prepend MPI libs (so would need to traverse right-to-left in list)
          for lib in $ADIOS2_REQ_LIBS ; do
              mpi_libs="$mpi_libs ${lib}_mpi"
          done
          ADIOS2_LIBS="$mpi_libs $ADIOS2_LIBS"
      fi
    fi
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
    # Fortran modules may be located in the lib directory
    ADIOS2_INC_DIRS="$ADIOS2_LIB_DIRS $ADIOS2_INC_DIRS"
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

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "ADIOS2_BUILD          = ${ADIOS2_BUILD}"
echo "ADIOS2_DIR            = ${ADIOS2_DIR}"
echo "ADIOS2_ENABLE_FORTRAN = ${ADIOS2_ENABLE_FORTRAN}"
echo "ADIOS2_ENABLE_SST     = ${ADIOS2_ENABLE_SST}"
echo "ADIOS2_INC_DIRS       = ${ADIOS2_INC_DIRS} ${ZLIB_INC_DIRS}"
echo "ADIOS2_LIB_DIRS       = ${ADIOS2_LIB_DIRS} ${ZLIB_LIB_DIRS}"
echo "ADIOS2_LIBS           = ${ADIOS2_LIBS}"
echo "ADIOS2_INSTALL_DIR    = ${ADIOS2_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

echo "BEGIN DEFINE"
if [ -n "${MPI_DIR+set}" ]; then
echo "ADIOS2_USE_MPI 1"
fi
echo "END DEFINE"

echo 'INCLUDE_DIRECTORY $(ADIOS2_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(ADIOS2_LIB_DIRS)'
echo 'LIBRARY           $(ADIOS2_LIBS)'
