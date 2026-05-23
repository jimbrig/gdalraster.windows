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
    -DGDAL_HIDE_INTERNAL_SYMBOLS=ON \
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

echo ""
echo ">>> Build complete."
echo "    DLL: ${INSTALL_DIR}/bin/libgdal-39.dll"
ls -lh "${INSTALL_DIR}/bin/libgdal-39.dll"
