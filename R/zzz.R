#' @keywords internal
#' @noRd
.onAttach <- function(libname, pkgname) {
  bundle <- installed_bundle_manifest()
  build <- installed_build_manifest()
  if (!build_is_current(bundle, build)) {
    build <- installed_build_manifest(.libPaths()[[1L]])
  }
  if (build_is_current(bundle, build)) {
    packageStartupMessage(
      cli::format_inline(
        "{.pkg gdalraster.windows} is ready; run {.fn gdal_verify} for a fresh-process check."
      )
    )
  } else {
    packageStartupMessage(
      cli::format_inline(
        "{.pkg gdalraster.windows} setup is incomplete; run {.fn gdal_sitrep} or {.fn gdal_setup}."
      )
    )
  }
  invisible(NULL)
}
