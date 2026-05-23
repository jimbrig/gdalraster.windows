#!/usr/bin/env bash
# =============================================================================
# collect_dlls.sh — Assemble a self-contained GDAL runtime bundle
#
# Takes the cmake-installed GDAL tree (INSTALL_DIR) and produces a bundle
# (BUNDLE_DIR) containing:
#   bin/    — libgdal-39.dll + all non-Windows transitive deps
#   include/ — public headers (for compiling against the bundle)
#   lib/     — import libraries (.dll.a) (for linking against the bundle)
#
# The goal is that BUNDLE_DIR/bin/*.dll should load with zero external deps
# beyond standard Windows system DLLs (kernel32, msvcrt, ucrtbase, etc.)
#
# Uses ntldd (recursive DLL dependency walker) to find all transitive deps
# and copies any that resolve to /ucrt64/ (i.e. MSYS2 UCRT64 packages that
# would not be present on the end-user machine).
# =============================================================================
set -euo pipefail

: "${INSTALL_DIR:?INSTALL_DIR must be set}"
: "${BUNDLE_DIR:?BUNDLE_DIR must be set}"

echo "============================================"
echo "  Assembling GDAL bundle"
echo "  Source: ${INSTALL_DIR}"
echo "  Output: ${BUNDLE_DIR}"
echo "============================================"

# ── Create bundle structure ───────────────────────────────────────────────────
mkdir -p "${BUNDLE_DIR}/bin" "${BUNDLE_DIR}/include" "${BUNDLE_DIR}/lib"

# ── Copy headers and import libraries ────────────────────────────────────────
echo ""
echo ">>> Copying headers and import libs"
cp -r "${INSTALL_DIR}/include/." "${BUNDLE_DIR}/include/"
# Copy only .dll.a (import libs) and .la — not static .a (too large, not needed)
find "${INSTALL_DIR}/lib" \( -name "*.dll.a" -o -name "*.la" \) \
    -exec cp {} "${BUNDLE_DIR}/lib/" \;

# ── Copy primary DLLs from install prefix ────────────────────────────────────
echo ""
echo ">>> Copying primary DLLs from install prefix"
cp "${INSTALL_DIR}/bin/"*.dll "${BUNDLE_DIR}/bin/" 2>/dev/null || true
DLL_COUNT=$(ls "${BUNDLE_DIR}/bin/"*.dll 2>/dev/null | wc -l)
echo "    Primary DLLs copied: ${DLL_COUNT}"

# ── Walk transitive dependencies with ntldd ───────────────────────────────────
# ntldd -R performs a recursive walk of the dependency tree.
# We filter for paths under /ucrt64/ — these are MSYS2 UCRT64 packages
# that won't exist on a plain Windows machine.
# We exclude:
#   - C:/Windows     : OS-provided, always available
#   - api-ms-*       : Windows API sets, always available
#   - system32       : OS system directory
#   - ext-ms-*       : Windows extended API sets
echo ""
echo ">>> Walking transitive DLL dependencies (ntldd -R)"

GDAL_DLL="${BUNDLE_DIR}/bin/libgdal-39.dll"

ntldd -R "${GDAL_DLL}" \
    | grep -i '/ucrt64/' \
    | grep -iv 'C:/Windows' \
    | grep -iv 'system32' \
    | grep -iv 'api-ms-' \
    | grep -iv 'ext-ms-' \
    | awk '{print $3}' \
    | sort -u \
    | while IFS= read -r dep; do
        if [[ -f "${dep}" ]]; then
            dest="${BUNDLE_DIR}/bin/$(basename ${dep})"
            if [[ ! -f "${dest}" ]]; then
                cp "${dep}" "${dest}"
                echo "    + Bundled: $(basename ${dep})"
            fi
        else
            echo "    ? Skipped (not a file): ${dep}"
        fi
    done

# ── Verify: remaining external deps should be Windows-only ────────────────────
echo ""
echo "============================================"
echo "  Verification — External deps remaining"
echo "  (should list ONLY Windows system DLLs)"
echo "============================================"

REMAINING=$(ntldd -R "${GDAL_DLL}" \
    | grep -iv 'C:/Windows' \
    | grep -iv 'system32' \
    | grep -iv 'api-ms-' \
    | grep -iv 'ext-ms-' \
    | grep -iv "${BUNDLE_DIR}/bin" \
    | grep -v "^$" || true)

if [[ -n "${REMAINING}" ]]; then
    echo ""
    echo "WARNING: The following external deps could not be bundled:"
    echo "${REMAINING}"
    echo ""
    echo "These may cause LoadLibrary failures on machines without Rtools/MSYS2."
    echo "Consider adding the relevant packages to the build_gdal.sh install list."
else
    echo ""
    echo "✓ PASS — Bundle is fully self-contained (no external non-Windows deps)"
fi

# ── Final inventory ───────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Bundle inventory"
echo "============================================"
echo "DLLs:"
ls -lh "${BUNDLE_DIR}/bin/"*.dll | awk '{printf "  %-50s %s\n", $NF, $5}'
echo ""
echo "Headers (count): $(find "${BUNDLE_DIR}/include" -name '*.h' | wc -l)"
echo "Import libs:     $(ls "${BUNDLE_DIR}/lib/"*.dll.a 2>/dev/null | wc -l)"
echo ""
TOTAL=$(du -sh "${BUNDLE_DIR}" | cut -f1)
echo "Total bundle size: ${TOTAL}"
