#!/usr/bin/env bash
# =============================================================================
# build_arrow.sh — Build static Apache Arrow for the GDAL Windows bundle
#
# Arrow is built with the MSYS2 UCRT64/MinGW toolchain used for GDAL and
# installed to a dedicated prefix. GDAL then folds these static libraries into
# libgdal-*.dll. Shared Arrow/Parquet/Thrift DLLs are intentionally excluded:
# the previous shared libarrow.dll crashed during lazy MinGW emulated-TLS
# initialization when loaded into TLS-heavy R processes.
#
# Environment variables (set by the GitHub Actions workflow):
#   ARROW_VER         : Apache Arrow release version, e.g. "25.0.0"
#   ARROW_INSTALL_DIR : cmake install prefix consumed by build_gdal.sh
# =============================================================================
set -euo pipefail

: "${ARROW_VER:?ARROW_VER must be set}"
: "${ARROW_INSTALL_DIR:?ARROW_INSTALL_DIR must be set}"

echo "============================================"
echo "  Building static Apache Arrow ${ARROW_VER}"
echo "  Install prefix: ${ARROW_INSTALL_DIR}"
echo "============================================"

SRC_DIR="/tmp/arrow-src"
ARROW_TAG="apache-arrow-${ARROW_VER}"

if [[ -d "${SRC_DIR}/.git" ]]; then
    echo ">>> Reusing existing clone at ${SRC_DIR}"
    git -C "${SRC_DIR}" fetch --depth=1 origin \
        "refs/tags/${ARROW_TAG}:refs/tags/${ARROW_TAG}" 2>/dev/null || true
    git -C "${SRC_DIR}" checkout "${ARROW_TAG}"
else
    echo ">>> Cloning Apache Arrow ${ARROW_VER} (shallow)"
    git clone \
        --depth=1 \
        --branch="${ARROW_TAG}" \
        https://github.com/apache/arrow.git \
        "${SRC_DIR}"
fi

rm -rf "${SRC_DIR}/cpp/build" "${ARROW_INSTALL_DIR}"

# Arrow's bundled dependency mode produces libarrow_bundled_dependencies.a and
# keeps compression libraries and Thrift out of the runtime DLL closure. The
# system allocator avoids the mimalloc/jemalloc TLS state implicated by the
# original first-Parquet-open crash.
echo ""
echo ">>> cmake configure"
cmake -S "${SRC_DIR}/cpp" -B "${SRC_DIR}/cpp/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${ARROW_INSTALL_DIR}" \
    -DCMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG" \
    -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG" \
    -DBUILD_SHARED_LIBS=OFF \
    \
    -DARROW_BUILD_STATIC=ON \
    -DARROW_BUILD_SHARED=OFF \
    -DARROW_DEPENDENCY_SOURCE=BUNDLED \
    -DARROW_DEPENDENCY_USE_SHARED=OFF \
    -DARROW_THRIFT_USE_SHARED=OFF \
    \
    -DARROW_PARQUET=ON \
    -DARROW_DATASET=ON \
    -DARROW_ACERO=ON \
    -DARROW_COMPUTE=ON \
    -DARROW_FILESYSTEM=ON \
    \
    -DARROW_MIMALLOC=OFF \
    -DARROW_JEMALLOC=OFF \
    -DARROW_WITH_BROTLI=ON \
    -DARROW_WITH_BZ2=ON \
    -DARROW_WITH_LZ4=ON \
    -DARROW_WITH_SNAPPY=ON \
    -DARROW_WITH_ZLIB=ON \
    -DARROW_WITH_ZSTD=ON \
    \
    -DARROW_BUILD_BENCHMARKS=OFF \
    -DARROW_BUILD_EXAMPLES=OFF \
    -DARROW_BUILD_INTEGRATION=OFF \
    -DARROW_BUILD_TESTS=OFF \
    -DARROW_BUILD_UTILITIES=OFF \
    -DARROW_CSV=OFF \
    -DARROW_FLIGHT=OFF \
    -DARROW_GANDIVA=OFF \
    -DARROW_HDFS=OFF \
    -DARROW_JSON=OFF \
    -DARROW_S3=OFF \
    -DPARQUET_BUILD_EXECUTABLES=OFF \
    -DPARQUET_REQUIRE_ENCRYPTION=OFF

NCPUS=$(nproc)
echo ""
echo ">>> cmake build (${NCPUS} cores)"
cmake --build "${SRC_DIR}/cpp/build" -j"${NCPUS}"

echo ""
echo ">>> cmake install -> ${ARROW_INSTALL_DIR}"
cmake --install "${SRC_DIR}/cpp/build"

required_targets=(
    "Arrow/ArrowConfig.cmake"
    "ArrowDataset/ArrowDatasetConfig.cmake"
    "ArrowCompute/ArrowComputeConfig.cmake"
    "Parquet/ParquetConfig.cmake"
)
for config in "${required_targets[@]}"; do
    if [[ ! -f "${ARROW_INSTALL_DIR}/lib/cmake/${config}" ]]; then
        echo "FATAL: required static Arrow CMake target missing: ${config}"
        exit 1
    fi
done

if ! compgen -G "${ARROW_INSTALL_DIR}/lib/libarrow*.a" >/dev/null; then
    echo "FATAL: no static Arrow libraries were installed"
    exit 1
fi
if ! compgen -G "${ARROW_INSTALL_DIR}/lib/libparquet*.a" >/dev/null; then
    echo "FATAL: no static Parquet libraries were installed"
    exit 1
fi
if [[ ! -f "${ARROW_INSTALL_DIR}/lib/libarrow_bundled_dependencies.a" ]]; then
    echo "FATAL: bundled static Arrow dependencies were not installed"
    exit 1
fi
if compgen -G "${ARROW_INSTALL_DIR}/bin/*.dll" >/dev/null; then
    echo "FATAL: static Arrow prefix unexpectedly contains DLLs:"
    printf '  %s\n' "${ARROW_INSTALL_DIR}"/bin/*.dll
    exit 1
fi

echo ""
echo ">>> Static Arrow build complete."
echo "    Libraries:"
printf '  %s\n' "${ARROW_INSTALL_DIR}"/lib/libarrow*.a
printf '  %s\n' "${ARROW_INSTALL_DIR}"/lib/libparquet*.a
