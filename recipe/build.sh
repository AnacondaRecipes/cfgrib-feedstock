#!/bin/bash
set -ex

${PYTHON} -m pip install . -vv --no-deps --no-build-isolation

# Embed SBOM in package
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
    {"type": "library", "name": "attrs", "purl": "pkg:conda/attrs"},
    {"type": "library", "name": "click", "purl": "pkg:conda/click"},
    {"type": "library", "name": "packaging", "purl": "pkg:conda/packaging"},
    {"type": "library", "name": "python-eccodes", "purl": "pkg:conda/python-eccodes"},
    {"type": "library", "name": "numpy", "purl": "pkg:conda/numpy"},
    {"type": "library", "name": "setuptools", "purl": "pkg:conda/setuptools"},
    {"type": "library", "name": "xarray", "purl": "pkg:conda/xarray"}
  ]
}
SBOM_EOF
