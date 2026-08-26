@echo off
setlocal EnableDelayedExpansion

REM =============================================================================
REM Bundled build: eccodes (C) -> findlibs (Python) -> python-eccodes -> cfgrib
REM =============================================================================

REM Save the main package version for later
set CFGRIB_VERSION=%PKG_VERSION%

REM -----------------------------------------------------------------------------
REM 1. Build eccodes C library
REM -----------------------------------------------------------------------------
echo === Building eccodes C library ===

mkdir %SRC_DIR%\eccodes\build
cd %SRC_DIR%\eccodes\build

set CFLAGS=
set CXXFLAGS=

cmake -G "NMake Makefiles" ^
      -D CMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
      -D CMAKE_BUILD_TYPE=Release ^
      -D INSTALL_LIB_DIR=lib ^
      -D JASPER_INCLUDE_DIR=%LIBRARY_INC% ^
      -D JASPER_PATH=%LIBRARY_PREFIX% ^
      -D ENABLE_FORTRAN=0 ^
      -D ENABLE_PYTHON=0 ^
      -D ENABLE_NETCDF=1 ^
      -D ENABLE_JPG=1 ^
      -D ENABLE_PNG=1 ^
      -D ENABLE_AEC=1 ^
      -D ENABLE_ECCODES_THREADS=1 ^
      -D IEEE_LE=1 ^
      -D ENABLE_MEMFS=1 ^
      -D ENABLE_EXTRA_TESTS=OFF ^
      %SRC_DIR%\eccodes
if errorlevel 1 exit 1

nmake
if errorlevel 1 exit 1

nmake install
if errorlevel 1 exit 1

REM -----------------------------------------------------------------------------
REM 2. Install findlibs (pure Python, no deps)
REM -----------------------------------------------------------------------------
echo === Installing findlibs ===
cd %SRC_DIR%\findlibs
set SETUPTOOLS_SCM_PRETEND_VERSION=0.1.3
%PYTHON% -m pip install . -vv --no-deps --no-build-isolation
if errorlevel 1 exit 1

REM -----------------------------------------------------------------------------
REM 3. Install python-eccodes (needs eccodes C library and findlibs)
REM -----------------------------------------------------------------------------
echo === Installing python-eccodes ===
cd %SRC_DIR%\python-eccodes
set SETUPTOOLS_SCM_PRETEND_VERSION=2.48.0
%PYTHON% builder.py
if errorlevel 1 exit 1
%PYTHON% -m pip install . -vv --no-deps --no-build-isolation
if errorlevel 1 exit 1

REM -----------------------------------------------------------------------------
REM 4. Install cfgrib (needs python-eccodes)
REM -----------------------------------------------------------------------------
echo === Installing cfgrib ===
cd %SRC_DIR%
set SETUPTOOLS_SCM_PRETEND_VERSION=%CFGRIB_VERSION%
%PYTHON% -m pip install . -vv --no-deps --no-build-isolation
if errorlevel 1 exit 1

REM -----------------------------------------------------------------------------
REM 5. Embed SBOM in package
REM -----------------------------------------------------------------------------
set SBOM_DIR=%PREFIX%\share\sbom
mkdir %SBOM_DIR% 2>nul

(
echo {
echo   "bomFormat": "CycloneDX",
echo   "specVersion": "1.5",
echo   "version": 1,
echo   "metadata": {
echo     "component": {
echo       "type": "library",
echo       "name": "cfgrib",
echo       "version": "0.9.15.1",
echo       "purl": "pkg:conda/cfgrib@0.9.15.1",
echo       "licenses": [{"license": {"id": "Apache-2.0"}}]
echo     }
echo   },
echo   "components": [
echo     {"type": "library", "name": "eccodes", "version": "2.48.0", "purl": "pkg:conda/eccodes@2.48.0"},
echo     {"type": "library", "name": "findlibs", "version": "0.1.3", "purl": "pkg:conda/findlibs@0.1.3"},
echo     {"type": "library", "name": "python-eccodes", "version": "2.48.0", "purl": "pkg:conda/python-eccodes@2.48.0"}
echo   ]
echo }
) > %SBOM_DIR%\%PKG_NAME%-%PKG_VERSION%.cdx.json
