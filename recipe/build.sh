#!/usr/bin/env bash
set -ex

# =============================================================================
# Bundled build: eccodes (C) -> findlibs (Python) -> python-eccodes -> cfgrib
# =============================================================================

# Save the main package version for later
CFGRIB_VERSION="${PKG_VERSION}"

# -----------------------------------------------------------------------------
# 1. Build eccodes C library
# -----------------------------------------------------------------------------
echo "=== Building eccodes C library ==="

if [[ "$c_compiler" == "gcc" ]]; then
  export PATH="${PATH}:${BUILD_PREFIX}/${HOST}/sysroot/usr/lib"
fi

export BUILD_FORTRAN=1
export BUILD_JPEG=1
export EXTRA_TESTS=1

if [[ $HOST =~ darwin ]]; then
  export LIBRARY_SEARCH_VAR=DYLD_FALLBACK_LIBRARY_PATH
  export FFLAGS="-isysroot $CONDA_BUILD_SYSROOT $FFLAGS"
  export CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
  export REPLACE_TPL_ABSOLUTE_PATHS=1
  if [[ $HOST =~ arm64 ]]; then
    export MACOS_LE_FLAG="-D IEEE_LE=1"
    export BUILD_FORTRAN=0
  fi
elif [[ $HOST =~ linux ]]; then
  export LIBRARY_SEARCH_VAR=LD_LIBRARY_PATH
  export REPLACE_TPL_ABSOLUTE_PATHS=1
fi

export PYTHON=
export LDFLAGS="$LDFLAGS -L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
export CFLAGS="$CFLAGS -fPIC -I$PREFIX/include"

mkdir -p $SRC_DIR/eccodes/build && cd $SRC_DIR/eccodes/build

cmake -D CMAKE_INSTALL_PREFIX=$PREFIX \
      -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_FIND_FRAMEWORK=LAST \
      -D CMAKE_LIBRARY_PATH=$PREFIX/lib \
      -D CMAKE_INCLUDE_PATH=$PREFIX/include \
      -D INSTALL_LIB_DIR='lib' \
      -D ENABLE_JPG=$BUILD_JPEG \
      -D ENABLE_JPG_LIBJASPER=ON \
      -D ENABLE_JPG_LIBOPENJPEG=OFF \
      -D ENABLE_NETCDF=1 \
      -D ENABLE_PNG=1 \
      -D ENABLE_PYTHON=0 \
      -D ENABLE_FORTRAN=$BUILD_FORTRAN \
      -D ENABLE_ECCODES_THREADS=1 \
      -D ENABLE_AEC=1 \
      -D ENABLE_EXTRA_TESTS=$EXTRA_TESTS \
      -D ECBUILD_DOWNLOAD_TIMEOUT=60 \
      -D REPLACE_TPL_ABSOLUTE_PATHS=$REPLACE_TPL_ABSOLUTE_PATHS \
      -D CMAKE_FIND_ROOT_PATH=$PREFIX \
      -D CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
      -D CMAKE_PROGRAM_PATH=$BUILD_PREFIX \
      $MACOS_LE_FLAG \
      $SRC_DIR/eccodes

make -j $CPU_COUNT VERBOSE=1
make install

# Restore PYTHON for pip installs
export PYTHON="${PREFIX}/bin/python"

# -----------------------------------------------------------------------------
# 2. Install findlibs (pure Python, no deps)
# -----------------------------------------------------------------------------
echo "=== Installing findlibs ==="
cd $SRC_DIR/findlibs
export SETUPTOOLS_SCM_PRETEND_VERSION="0.1.3"
${PYTHON} -m pip install . -vv --no-deps --no-build-isolation

# -----------------------------------------------------------------------------
# 3. Install python-eccodes (needs eccodes C library and findlibs)
# -----------------------------------------------------------------------------
echo "=== Installing python-eccodes ==="
cd $SRC_DIR/python-eccodes
echo "recursive-include gribapi *.so" >> MANIFEST.in
export SETUPTOOLS_SCM_PRETEND_VERSION="2.48.0"
${PYTHON} builder.py
${PYTHON} -m pip install . -vv --no-deps --no-build-isolation

# -----------------------------------------------------------------------------
# 4. Install cfgrib (needs python-eccodes)
# -----------------------------------------------------------------------------
echo "=== Installing cfgrib ==="
cd $SRC_DIR
export SETUPTOOLS_SCM_PRETEND_VERSION="${CFGRIB_VERSION}"
${PYTHON} -m pip install . -vv --no-deps --no-build-isolation

# -----------------------------------------------------------------------------
# 5. Embed SBOM in package
# -----------------------------------------------------------------------------
SBOM_DIR="${PREFIX}/share/sbom"
mkdir -p "${SBOM_DIR}"

cat > "${SBOM_DIR}/${PKG_NAME}-${PKG_VERSION}.cdx.json" << 'SBOM_EOF'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "version": 1,
  "metadata": {
    "component": {
      "type": "library",
      "name": "cfgrib",
      "version": "0.9.15.1",
      "purl": "pkg:conda/cfgrib@0.9.15.1",
      "licenses": [{"license": {"id": "Apache-2.0"}}]
    }
  },
  "components": [
    {"type": "library", "name": "eccodes", "version": "2.48.0", "purl": "pkg:conda/eccodes@2.48.0"},
    {"type": "library", "name": "findlibs", "version": "0.1.3", "purl": "pkg:conda/findlibs@0.1.3"},
    {"type": "library", "name": "python-eccodes", "version": "2.48.0", "purl": "pkg:conda/python-eccodes@2.48.0"},
    {"type": "library", "name": "attrs", "purl": "pkg:conda/attrs"},
    {"type": "library", "name": "click", "purl": "pkg:conda/click"},
    {"type": "library", "name": "packaging", "purl": "pkg:conda/packaging"},
    {"type": "library", "name": "numpy", "purl": "pkg:conda/numpy"},
    {"type": "library", "name": "cffi", "purl": "pkg:conda/cffi"},
    {"type": "library", "name": "xarray", "purl": "pkg:conda/xarray"}
  ]
}
SBOM_EOF
