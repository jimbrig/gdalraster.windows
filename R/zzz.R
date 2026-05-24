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

  auto_bootstrap <- getOption("gdalraster.windows.auto_bootstrap", default = TRUE)
  if (isTRUE(auto_bootstrap)) {
    try(startup_bootstrap(), silent = TRUE)
  }
}

# onAttach --------------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
.onAttach <- function(libname, pkgname) {
  if (!startup_sitrep_enabled()) {
    return(invisible(NULL))
  }

  st <- runtime_sitrep()
  msg <- pkg_startup_msg()
  if (st$gdalraster_loaded && !st$custom_gdalraster_exists) {
    cli::cli_alert_info(msg[[1]])
    if (length(msg) > 1L) {
      cli::cli_inform(setNames(as.list(msg[-1]), rep("i", length(msg) - 1L)))
    }
    cli::cli_alert_warning(
      paste(
        "gdalraster was already loaded before gdalraster.windows;",
        "restart session for full bootstrap control."
      )
    )
    return(invisible(NULL))
  }
  cli::cli_alert_info(msg[[1]])
  if (length(msg) > 1L) {
    cli::cli_inform(setNames(as.list(msg[-1]), rep("i", length(msg) - 1L)))
  }
}

# onUnload --------------------------------------------------------------------------------------------------------

.onUnload <- function(libpath) {
  # rlang::try_fetch({ ... }, error = function(e) NULL)
}
