#  ------------------------------------------------------------------------
#
# Title : package onLoad and onAttach
#    By : Jimmy Briggs
#  Date : 2026-05-23
#
#  ------------------------------------------------------------------------

# environment -----------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
#' @importFrom rlang new_environment
.pkg_env <- rlang::new_environment()

# initializers ----------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
#' @importFrom rlang on_load local_use_cli
rlang::on_load({
  init_pkg_env()
  rlang::local_use_cli()
})

# onLoad ----------------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
#' @importFrom rlang run_on_load
.onLoad <- function(libname, pkgname) {
  rlang::run_on_load()

  auto_activate <- getOption("gdalraster.windows.auto_activate", default = TRUE)
  if (isTRUE(auto_activate)) {
    activate_fun <- get0("activate_gdal_runtime", mode = "function")
    if (!is.null(activate_fun)) {
      try(activate_fun(quiet = TRUE), silent = TRUE)
    }
  }
}

# onAttach --------------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
.onAttach <- function(libname, pkgname) {
  if (isTRUE(getOption("gdalraster.windows.auto_activate", default = TRUE))) {
    home <- default_gdal_home()
    if (dir.exists(home)) {
      packageStartupMessage(
        "gdal runtime home: ",
        normalizePath(home, winslash = "/", mustWork = FALSE)
      )
    }
  }
}

# onUnload --------------------------------------------------------------------------------------------------------

.onUnload <- function(libpath) {
  # rlang::try_fetch({ ... }, error = function(e) NULL)
}
