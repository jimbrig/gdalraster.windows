#!/usr/bin/env bash
# =============================================================================
# build_gdal.sh — Build GDAL from source in MSYS2 UCRT64
#
# Environment variables (set by the GitHub Actions workflow):
#   GDAL_VER    : git tag to check out, e.g. "v3.13.0"
#   BUNDLE_DIR  : absolute path where the final bundle should land
#   INSTALL_DIR : cmake install prefix (intermediate, collected by collect_dlls.sh)
#
# Key build decisions:
#   - Static GCC/stdc++/winpthread runtime — the DLLs carry their own C++
#     runtime, so neither Rtools nor a specific MSYS2 installation is required
#     on the end-user machine. This is the single most important flag for
#     distribution.
#   - --kill-at — required for correct stdcall symbol decoration in MinGW
#     DLLs used from R (GDAL's Windows exports use __stdcall).
#   - GDAL_USE_MUPARSER=ON — enables the Algorithmic Processing API
#     (gdal_global_reg_names() returns non-empty on Windows).
#   - BUILD_TESTING=OFF, BUILD_APPS=OFF — reduces build time by ~30%.
#   - GDAL_HIDE_INTERNAL_SYMBOLS=ON — cleaner export table.
#   - GDAL_USE_MSSQL_ODBC/NCLI=OFF — GitHub runner images ship the proprietary
#     "Microsoft ODBC Driver 17 for SQL Server" SDK; when auto-detected, GDAL
#     links libgdal directly against msodbcsql17.dll, which is NOT an
#     OS-provided DLL and breaks LoadLibrary on end-user machines that don't
#     have that driver installed. The MSSQLSpatial driver falls back to the
#     generic ODBC32-based path (same as the MSYS2 gdal package).
#   - GDAL_USE_HDF5=OFF, GDAL_USE_NETCDF=OFF — HDF5 (and its dependent
#     NetCDF) pulls in libopenblas → libgfortran-5/libgomp-1/libquadmath-0.
#     R on Windows (Rtools45) already loads its own versions of libgfortran
#     and libgomp at process startup. Windows' "loaded-module list" rule means
#     these Rtools copies are reused by any subsequently loaded DLL, even when
#     a different version lives in the bundle's bin/. When the Rtools and MSYS2
#     versions diverge (e.g. GCC 14 vs GCC 15 snapshot) the mismatched
#     libopenblas DllMain returns FALSE → ERROR_DLL_INIT_FAILED (1114) for
#     libgdal itself. Disabling HDF5/NetCDF eliminates the entire
#     OpenBLAS/Fortran/OpenMP dependency chain from the bundle.
#   - GDAL_USE_POPPLER=OFF — Poppler links against Mozilla NSS/NSPR
#     (libnspr4/nss3/nssutil3) which perform process-wide initialization on
#     load. On locked-down Windows environments this can also produce
#     ERROR_DLL_INIT_FAILED. PDF driver support is rarely needed in R spatial
#     workflows, so disabling it is a safe trade-off.
# =============================================================================
set -euo pipefail

# ── Validate env ──────────────────────────────────────────────────────────────
: "${GDAL_VER:?GDAL_VER must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"

echo "============================================"
echo "  Building GDAL ${GDAL_VER}"
echo "  Install prefix: ${INSTALL_DIR}"
echo "============================================"

# ── Clone ─────────────────────────────────────────────────────────────────────
SRC_DIR="/tmp/gdal-src"

if [[ -d "${SRC_DIR}/.git" ]]; then
    echo ">>> Reusing existing clone at ${SRC_DIR}"
    git -C "${SRC_DIR}" fetch --depth=1 origin "refs/tags/${GDAL_VER}:refs/tags/${GDAL_VER}" 2>/dev/null || true
    git -C "${SRC_DIR}" checkout "${GDAL_VER}"
else
    echo ">>> Cloning GDAL ${GDAL_VER} (shallow)"
    git clone \
        --depth=1 \
        --branch="${GDAL_VER}" \
        https://github.com/OSGeo/gdal.git \
        "${SRC_DIR}"
fi

cd "${SRC_DIR}"

# Clean any previous build tree
rm -rf build

# ── Static runtime flags ──────────────────────────────────────────────────────
# -static-libgcc -static-libstdc++   : embed GCC/stdc++ runtime into the DLL
# -Wl,-Bstatic,--whole-archive \
#   -lwinpthread                      : embed pthreads-win32 statically
# -Wl,-Bdynamic,--no-whole-archive   : revert to dynamic for everything after
STATIC_RT="-static-libgcc -static-libstdc++ -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,-Bdynamic,--no-whole-archive"

# ── Configure ─────────────────────────────────────────────────────────────────
echo ""
echo ">>> cmake configure"
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_PREFIX_PATH=/ucrt64 \
    \
    -DGDAL_USE_MUPARSER=ON \
    -DGDAL_USE_ARROW=ON \
    -DGDAL_USE_PARQUET=ON \
    -DGDAL_USE_GEOS=ON \
    -DGDAL_USE_SPATIALITE=ON \
    -DGDAL_HIDE_INTERNAL_SYMBOLS=ON \
    \
    -DGDAL_USE_HDF5=OFF \
    -DGDAL_USE_NETCDF=OFF \
    -DGDAL_USE_POPPLER=OFF \
    -DGDAL_USE_MSSQL_ODBC=OFF \
    -DGDAL_USE_MSSQL_NCLI=OFF \
    \
    -DBUILD_TESTING=OFF \
    -DBUILD_APPS=OFF \
    -DGDAL_BUILD_OPTIONAL_DRIVERS=ON \
    -DOGR_BUILD_OPTIONAL_DRIVERS=ON \
    \
    "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--kill-at ${STATIC_RT}" \
    "-DCMAKE_MODULE_LINKER_FLAGS=-Wl,--kill-at ${STATIC_RT}"

# ── Build ─────────────────────────────────────────────────────────────────────
NCPUS=$(nproc)
echo ""
echo ">>> cmake build (${NCPUS} cores)"
cmake --build build -j"${NCPUS}"

# ── Install ───────────────────────────────────────────────────────────────────
echo ""
echo ">>> cmake install → ${INSTALL_DIR}"
cmake --install build

# ── Stage pure-python GDAL utilities (osgeo_utils) ────────────────────────────
# GDAL algorithms that embed Python at runtime (e.g. `gdal driver gpkg
# validate`) import the osgeo_utils package. It is pure python (no compiled
# extensions), lives in the GDAL source tree, and is version-locked to the
# tag we just built. Staging it under <prefix>/python lets the R runtime
# expose it to the embedded interpreter via PYTHONPATH.
echo ""
echo ">>> Staging osgeo_utils (gdal-utils) → ${INSTALL_DIR}/python"
mkdir -p "${INSTALL_DIR}/python"
cp -r "${SRC_DIR}/swig/python/gdal-utils/osgeo_utils" "${INSTALL_DIR}/python/"
PY_COUNT=$(find "${INSTALL_DIR}/python/osgeo_utils" -name '*.py' | wc -l)
echo "    osgeo_utils python files staged: ${PY_COUNT}"
if [[ ! -f "${INSTALL_DIR}/python/osgeo_utils/samples/validate_gpkg.py" ]]; then
    echo "FATAL: osgeo_utils/samples/validate_gpkg.py missing after staging"
    exit 1
fi

# discover the produced soname instead of hardcoding it; gdal bumps the
# soname each minor release (3.13 -> libgdal-39.dll, 3.14 -> libgdal-40.dll)
GDAL_DLL=$(ls "${INSTALL_DIR}/bin/libgdal-"*.dll 2>/dev/null | head -n1)
if [[ -z "${GDAL_DLL}" ]]; then
    echo "FATAL: no libgdal-*.dll found in ${INSTALL_DIR}/bin after build"
    exit 1
fi

echo ""
echo ">>> Build complete."
echo "    DLL: ${GDAL_DLL}"
ls -lh "${GDAL_DLL}"
