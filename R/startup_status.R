# startup state -----------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
runtime_sitrep <- function() {
  home <- default_gdal_home()
  bin <- gdal_bin_dir(home)
  dll <- gdal_dll_path(home)
  lib <- default_gdalraster_lib()
  has_custom <- dir.exists(file.path(lib, "gdalraster"))

  list(
    gdal_home = home,
    gdal_bin = bin,
    gdal_dll = dll,
    custom_lib = lib,
    gdal_home_exists = dir.exists(home),
    gdal_dll_exists = file.exists(dll),
    custom_lib_exists = dir.exists(lib),
    custom_gdalraster_exists = has_custom,
    gdalraster_loaded = "gdalraster" %in% loadedNamespaces()
  )
}

#' @keywords internal
#' @noRd
startup_sitrep_enabled <- function() {
  opt <- getOption("gdalraster.windows.startup.sitrep", default = interactive())
  isTRUE(opt)
}

#' @keywords internal
#' @noRd
startup_bootstrap <- function() {
  st <- runtime_sitrep()

  if (st$gdal_home_exists && st$gdal_dll_exists) {
    try(activate_gdal_runtime(gdal_home = st$gdal_home, preload = TRUE, quiet = TRUE), silent = TRUE)
  }

  if (st$custom_lib_exists && !st$custom_lib %in% .libPaths()) {
    .libPaths(c(st$custom_lib, .libPaths()))
  }

  auto_load <- getOption("gdalraster.windows.auto_load_gdalraster", default = FALSE)
  if (!isTRUE(auto_load)) {
    return(invisible(runtime_sitrep()))
  }

  st <- runtime_sitrep()
  if (st$gdalraster_loaded) {
    return(invisible(st))
  }

  if (st$custom_gdalraster_exists) {
    try(base::library("gdalraster", character.only = TRUE, lib.loc = st$custom_lib), silent = TRUE)
  }

  invisible(runtime_sitrep())
}

#' @keywords internal
#' @noRd
pkg_startup_msg <- function() {
  st <- runtime_sitrep()
  base <- paste0(pkg_name(), " v", pkg_version())

  if (st$gdalraster_loaded && st$gdal_dll_exists) {
    return(c(
      base,
      paste0("runtime: ", st$gdal_home),
      paste0("gdal dll: ", basename(st$gdal_dll)),
      paste0("gdalraster lib: ", st$custom_lib)
    ))
  }

  next_steps <- c(base, "streamline status: setup needed")
  if (!st$gdal_dll_exists) {
    next_steps <- c(
      next_steps,
      "run: gdalraster.windows::install_gdal_runtime()"
    )
  }
  if (!st$custom_gdalraster_exists) {
    next_steps <- c(
      next_steps,
      "run: gdalraster.windows::install_gdalraster()"
    )
  }
  next_steps <- c(
    next_steps,
    "run: gdalraster.windows::load_gdal_dll()",
    "run: gdalraster.windows::load_gdalraster()",
    "check: gdalraster::gdal_global_reg_names()"
  )

  next_steps
}
