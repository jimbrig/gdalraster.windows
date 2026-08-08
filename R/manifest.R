#' @keywords internal
#' @noRd
bundle_manifest_path <- function(gdal_home = default_gdal_home()) {
  file.path(gdal_home, "MANIFEST.dcf")
}

#' @keywords internal
#' @noRd
build_manifest_path <- function(pkg_dir) {
  file.path(pkg_dir, "gdalraster.windows-build.dcf")
}

#' @keywords internal
#' @noRd
read_manifest <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  manifest <- tryCatch(
    read.dcf(path),
    error = function(cnd) NULL
  )
  if (is.null(manifest) || nrow(manifest) != 1L) {
    return(NULL)
  }

  stats::setNames(as.list(manifest[1L, , drop = TRUE]), colnames(manifest))
}

#' @keywords internal
#' @noRd
write_manifest <- function(fields, path) {
  if (!is.list(fields) || is.null(names(fields)) || any(!nzchar(names(fields)))) {
    cli::cli_abort(
      "{.arg fields} must be a named list.",
      call = rlang::caller_env()
    )
  }

  values <- vapply(
    fields,
    function(value) paste(as.character(value), collapse = ", "),
    character(1)
  )
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.dcf(as.data.frame(as.list(values), check.names = FALSE), file = path)
  invisible(path)
}

#' @keywords internal
#' @noRd
manifest_value <- function(manifest, field, default = NA_character_) {
  if (is.null(manifest) || is.null(manifest[[field]]) || !nzchar(manifest[[field]])) {
    return(default)
  }
  as.character(manifest[[field]])
}

#' @keywords internal
#' @noRd
bundle_manifest <- function(
  tag,
  gdal_version = NA_character_,
  asset_name = NA_character_
) {
  list(
    `Bundle-Tag` = tag,
    `GDAL-Version` = gdal_version,
    `Asset-Name` = asset_name,
    `Installed-At` = format(Sys.time(), tz = "UTC", usetz = TRUE),
    `Installer-Version` = pkg_version()
  )
}

#' @keywords internal
#' @noRd
gdal_version_from_tag <- function(tag) {
  if (!is.character(tag) || length(tag) != 1L || !nzchar(tag)) {
    return(NA_character_)
  }
  sub("^gdal-v", "", tag)
}

#' @keywords internal
#' @noRd
installed_bundle_manifest <- function(gdal_home = default_gdal_home()) {
  read_manifest(bundle_manifest_path(gdal_home))
}

#' @keywords internal
#' @noRd
installed_build_manifest <- function(lib = default_gdalraster_lib()) {
  read_manifest(build_manifest_path(file.path(lib, "gdalraster")))
}

#' @keywords internal
#' @noRd
build_is_current <- function(bundle, build) {
  bundle_tag <- manifest_value(bundle, "Bundle-Tag")
  build_tag <- manifest_value(build, "Bundle-Tag")
  !is.na(bundle_tag) && !is.na(build_tag) && identical(bundle_tag, build_tag)
}
