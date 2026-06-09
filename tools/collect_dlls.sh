#!/usr/bin/env bash
# =============================================================================
# collect_dlls.sh — Assemble a self-contained GDAL runtime bundle
#
# Takes the cmake-installed GDAL tree (INSTALL_DIR) and produces a bundle
# (BUNDLE_DIR) containing:
#   bin/      — libgdal-39.dll + all non-Windows transitive deps
#   include/  — public headers (for compiling against the bundle)
#   lib/      — import libraries (.dll.a) (for linking against the bundle)
#   share/    — gdal/proj runtime data files
#   python/   — pure-python osgeo_utils package for embedded-python algorithms
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
mkdir -p "${BUNDLE_DIR}/bin" "${BUNDLE_DIR}/include" "${BUNDLE_DIR}/lib" "${BUNDLE_DIR}/share"

# ── Copy headers and import libraries ────────────────────────────────────────
echo ""
echo ">>> Copying headers and import libs"
cp -r "${INSTALL_DIR}/include/." "${BUNDLE_DIR}/include/"
# Copy only .dll.a (import libs) and .la — not static .a (too large, not needed)
find "${INSTALL_DIR}/lib" \( -name "*.dll.a" -o -name "*.la" \) \
    -exec cp {} "${BUNDLE_DIR}/lib/" \;

# Runtime data required for GDAL/PROJ behavior
if [[ -d "${INSTALL_DIR}/share" ]]; then
    cp -r "${INSTALL_DIR}/share/." "${BUNDLE_DIR}/share/"
fi

# Pure-python GDAL utilities staged by build_gdal.sh. Required by GDAL
# algorithms that embed Python at runtime (e.g. `gdal driver gpkg validate`).
if [[ -d "${INSTALL_DIR}/python" ]]; then
    echo ""
    echo ">>> Copying python utilities (osgeo_utils)"
    mkdir -p "${BUNDLE_DIR}/python"
    cp -r "${INSTALL_DIR}/python/." "${BUNDLE_DIR}/python/"
    echo "    python files: $(find "${BUNDLE_DIR}/python" -name '*.py' | wc -l)"
fi

# ── Copy primary DLLs from install prefix ────────────────────────────────────
echo ""
echo ">>> Copying primary DLLs from install prefix"
cp "${INSTALL_DIR}/bin/"*.dll "${BUNDLE_DIR}/bin/" 2>/dev/null || true
DLL_COUNT=$(ls "${BUNDLE_DIR}/bin/"*.dll 2>/dev/null | wc -l)
echo "    Primary DLLs copied: ${DLL_COUNT}"

# Copy PROJ data from UCRT64 prefix when not present in install prefix.
if [[ -d "/ucrt64/share/proj" && ! -d "${BUNDLE_DIR}/share/proj" ]]; then
    cp -r "/ucrt64/share/proj" "${BUNDLE_DIR}/share/"
fi

# Explicitly bundle GCC runtime safety-net DLLs.
for rt in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
    src="/ucrt64/bin/${rt}"
    dest="${BUNDLE_DIR}/bin/${rt}"
    if [[ -f "${src}" && ! -f "${dest}" ]]; then
        cp "${src}" "${dest}"
        echo "    + Bundled runtime: ${rt}"
    fi
done

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

GDAL_DLL=$(ls "${BUNDLE_DIR}/bin/libgdal-"*.dll 2>/dev/null | head -n 1 || true)
if [[ -z "${GDAL_DLL}" ]]; then
    echo "FATAL: No libgdal-*.dll found in ${BUNDLE_DIR}/bin"
    exit 1
fi

# Note: with "set -euo pipefail", grep returns 1 when there are no matches.
# That is valid here, so we parse defensively and never fail on "no deps found".
deps_to_copy="$(
    ntldd -R "${GDAL_DLL}" \
        | awk '
            {
                # Keep only lines with resolved "dll => path (" shape.
                if ($2 != "=>") next
                dep = $3
                low = tolower(dep)
                # Keep UCRT64 deps regardless of slash style.
                if (low !~ /[\\\/]ucrt64[\\\/]/) next
                # Exclude Windows/system API-set paths.
                if (low ~ /c:[\\\/]windows[\\\/]/) next
                if (low ~ /[\\\/]system32[\\\/]/) next
                if (low ~ /api-ms-/) next
                if (low ~ /ext-ms-/) next
                print dep
            }
        ' \
        | sort -u || true
)"

if [[ -z "${deps_to_copy}" ]]; then
    echo "    (no additional /ucrt64 deps reported by ntldd)"
else
    while IFS= read -r dep; do
        [[ -z "${dep}" ]] && continue
        if [[ -f "${dep}" ]]; then
            dep_base="$(basename "${dep}")"
            dest="${BUNDLE_DIR}/bin/${dep_base}"
            if [[ ! -f "${dest}" ]]; then
                cp "${dep}" "${dest}"
                echo "    + Bundled: ${dep_base}"
            fi
        else
            echo "    ? Skipped (not a file): ${dep}"
        fi
    done <<< "${deps_to_copy}"
fi

# ── Verify: remaining external deps should be Windows-only ────────────────────
echo ""
echo "============================================"
echo "  Verification — External deps remaining"
echo "  (should list ONLY Windows system DLLs)"
echo "============================================"

bundle_bin_norm="$(echo "${BUNDLE_DIR}/bin" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')"
allowed_not_found_regex='^(api-ms-.*|ext-ms-.*|ms-win-.*|pdmutilities\.dll|hvsifiletrust\.dll|wpaxholder\.dll|azureattestmanager\.dll|azureattestnormal\.dll|wtdccm\.dll|wtdsensor\.dll)$'
remaining_lines=()

while IFS='|' read -r entry_type dll_name dep_path; do
    [[ -z "${entry_type}" ]] && continue

    dll_lower="$(echo "${dll_name}" | tr '[:upper:]' '[:lower:]')"

    if [[ "${entry_type}" == "NOTFOUND" ]]; then
        if [[ "${dll_lower}" =~ ${allowed_not_found_regex} ]]; then
            continue
        fi
        remaining_lines+=("${dll_name} => not found")
        continue
    fi

    dep_norm="$(echo "${dep_path}" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')"
    dep_base="$(basename "${dep_path}")"

    if [[ "${dep_norm}" == *"/windows/"* ]]; then
        continue
    fi
    if [[ "${dep_norm}" == *"/system32/"* ]]; then
        continue
    fi
    if [[ "${dep_norm}" == api-ms-* || "${dep_norm}" == ext-ms-* ]]; then
        continue
    fi
    if [[ "${dep_norm}" == *"${bundle_bin_norm}"* ]]; then
        continue
    fi
    # ntldd can resolve to /ucrt64/bin due PATH precedence even when the same
    # DLL basename has already been copied into the bundle.
    if [[ -f "${BUNDLE_DIR}/bin/${dep_base}" ]]; then
        continue
    fi

    remaining_lines+=("${dll_name} => ${dep_path}")
done < <(
    ntldd -R "${GDAL_DLL}" \
        | awk '
            {
                if ($2 != "=>") next
                dll = $1
                dep = $3
                if (dep == "not" && tolower($4) == "found") {
                    print "NOTFOUND|" dll "|"
                } else {
                    print "RESOLVED|" dll "|" dep
                }
            }
        '
)

if (( ${#remaining_lines[@]} > 0 )); then
    echo ""
    echo "FATAL: The following external deps could not be bundled:"
    printf '%s\n' "${remaining_lines[@]}"
    echo ""
    echo "These may cause LoadLibrary failures on machines without Rtools/MSYS2."
    echo "Adjust package install set and dependency collection until only Windows system DLLs remain external."
    exit 1
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
echo "Python utils:    $(find "${BUNDLE_DIR}/python" -name '*.py' 2>/dev/null | wc -l) files"
echo ""
TOTAL=$(du -sh "${BUNDLE_DIR}" | cut -f1)
echo "Total bundle size: ${TOTAL}"
