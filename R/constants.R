#  ------------------------------------------------------------------------
#
# Title : package constants
#
# single source of truth for repo slugs, release asset patterns, and dll
# naming conventions used across the package. workflow-side counterparts
# (default gdal_version in .github/workflows/build.yml and the readme
# latest-release line) are release-time bookkeeping and are called out in
# the scheduled upstream-check issue template.
#
#  ------------------------------------------------------------------------

#' Repository publishing the GDAL runtime bundle releases (`gdal-v*` tags)
#' @keywords internal
#' @noRd
default_bundle_repo <- function() {
  "jimbrig/gdalraster.windows"
}

#' Upstream repository providing the gdalraster source tarball
#' @keywords internal
#' @noRd
default_gdalraster_repo <- function() {
  "firelab/gdalraster"
}

#' Regex selecting a runtime bundle zip among release assets
#' @keywords internal
#' @noRd
bundle_asset_pattern <- function() {
  "gdal-(bundle|ucrt64)-.*\\.zip$"
}

#' Regex matching the top-level GDAL runtime DLL (SONAME discovered by glob,
#' never hardcoded; see #2)
#' @keywords internal
#' @noRd
gdal_dll_name_pattern <- function() {
  "^libgdal-[0-9]+\\.dll$"
}

#' Concrete-but-arbitrary DLL filename used only to produce missing-file
#' error paths when no runtime DLL exists yet; never dyn.load()ed
#' @keywords internal
#' @noRd
gdal_dll_fallback_name <- function() {
  "libgdal-39.dll"
}
