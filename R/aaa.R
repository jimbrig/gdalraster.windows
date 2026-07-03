
#  ------------------------------------------------------------------------
#
# Title : Shared Package Resources
#    By : Jimmy Briggs
#  Date : 2026-07-03
#
#  ------------------------------------------------------------------------

# github repositories ------------------------------------------------------

#' Repository publishing the GDAL runtime bundle releases (`gdal-v*` tags)
#' @noRd
#' @keywords internal
.bundle_repo <- "jimbrig/gdalraster.windows"

#' Upstream repository providing the gdalraster source tarball
#' @noRd
#' @keywords internal
.gdalraster_repo <- "firelab/gdalraster"

# release assets ------------------------------------------------------------

#' Regex selecting a runtime bundle zip among release assets
#' @noRd
#' @keywords internal
.bundle_asset_pattern <- "gdal-(bundle|ucrt64)-.*\\.zip$"

# runtime dll naming --------------------------------------------------------

#' Regex matching the top-level GDAL runtime DLL (SONAME discovered by glob,
#' never hardcoded; see #2)
#' @noRd
#' @keywords internal
.gdal_dll_pattern <- "^libgdal-[0-9]+\\.dll$"

#' Concrete-but-arbitrary DLL filename used only to produce missing-file
#' error paths when no runtime DLL exists yet; never dyn.load()ed
#' @noRd
#' @keywords internal
.gdal_dll_fallback <- "libgdal-39.dll"
