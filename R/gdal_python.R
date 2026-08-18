#' Enable GDAL embedded-Python utilities
#'
#' Writes a managed `.pth` file into the system CPython `site-packages`
#' directory. The file points to the pure-Python `osgeo_utils` vendored inside
#' the installed `gdalraster` package. This does not modify `PYTHONPATH` and
#' does not affect isolated virtual environments.
#'
#' @param lib Library containing the self-contained `gdalraster` package.
#'   Defaults to `.libPaths()[1]`.
#' @param isolated Use the package-managed isolated library instead of
#'   `.libPaths()[1]`. Ignored when `lib` is set.
#' @param user_lib Deprecated. `user_lib = TRUE` is now the default;
#'   `user_lib = FALSE` is equivalent to `isolated = TRUE`.
#' @param python Optional path to the CPython executable GDAL embeds.
#' @param site_packages Optional explicit `site-packages` directory.
#' @param quiet Suppress status messages.
#'
#' @return Invisibly, the `.pth` path, or `NULL` when no system CPython can be
#'   located.
#' @export
gdal_enable_python <- function(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  python = NULL,
  site_packages = NULL,
  quiet = FALSE
) {
  abort_if_not_windows()
  check_flag(isolated)
  check_optional_flag(user_lib)
  check_optional_string(python)
  check_optional_string(site_packages)
  check_flag(quiet)

  lib <- resolve_gdalraster_lib(lib, isolated = isolated, user_lib = user_lib)

  package_python <- file.path(
    normalizePath(lib, winslash = "/", mustWork = FALSE),
    "gdalraster",
    "python"
  )
  if (!dir.exists(file.path(package_python, "osgeo_utils"))) {
    cli::cli_abort(
      c(
        "Vendored {.pkg osgeo_utils} was not found at {.path {package_python}}.",
        "i" = "Rebuild with {.fn gdal_build_gdalraster}."
      ),
      call = rlang::caller_env()
    )
  }

  if (is.null(site_packages)) {
    site_packages <- find_python_site_packages(python)
  }
  if (is.null(site_packages)) {
    if (!isTRUE(quiet)) {
      cli::cli_alert_warning(
        "No system CPython was found; core {.pkg gdalraster} is ready, but embedded-Python algorithms are not enabled."
      )
    }
    return(invisible(NULL))
  }

  site_packages <- normalizePath(site_packages, winslash = "/", mustWork = FALSE)
  dir.create(site_packages, recursive = TRUE, showWarnings = FALSE)
  pth <- file.path(site_packages, .python_pth_name)
  writeLines(
    c(.python_pth_marker, normalizePath(package_python, winslash = "/", mustWork = TRUE)),
    pth,
    useBytes = TRUE
  )
  if (!isTRUE(quiet)) {
    cli::cli_alert_success("Enabled embedded-Python utilities via {.path {pth}}.")
  }
  invisible(pth)
}

#' @keywords internal
#' @noRd
find_python_site_packages <- function(python = NULL) {
  commands <- if (!is.null(python)) {
    list(list(command = python, prefix = character()))
  } else {
    paths <- Sys.which(c("python", "python3", "py"))
    paths <- unique(unname(paths[nzchar(paths)]))
    lapply(paths, function(path) {
      list(
        command = path,
        prefix = if (identical(tolower(basename(path)), "py.exe")) "-3" else character()
      )
    })
  }

  expression <- paste0(
    "import sysconfig; ",
    "print(sysconfig.get_paths().get('purelib', ''))"
  )
  for (candidate in commands) {
    output <- suppressWarnings(
      tryCatch(
        system2(
          candidate$command,
          args = c(candidate$prefix, "-c", shQuote(expression)),
          stdout = TRUE,
          stderr = FALSE
        ),
        error = function(cnd) character()
      )
    )
    output <- trimws(output)
    output <- output[nzchar(output)]
    if (length(output) > 0L && dir.exists(output[[length(output)]])) {
      return(normalizePath(output[[length(output)]], winslash = "/", mustWork = TRUE))
    }
  }
  NULL
}

#' @keywords internal
#' @noRd
known_python_site_packages <- function() {
  discovered <- find_python_site_packages()
  local_app_data <- Sys.getenv("LOCALAPPDATA", unset = "")
  patterns <- c(
    "C:/Python*/Lib/site-packages",
    if (nzchar(local_app_data)) {
      file.path(local_app_data, "Programs", "Python", "Python*", "Lib", "site-packages")
    } else {
      character()
    }
  )
  unique(c(discovered, unlist(lapply(patterns, Sys.glob), use.names = FALSE)))
}

#' @keywords internal
#' @noRd
managed_python_pth_files <- function() {
  sites <- known_python_site_packages()
  paths <- file.path(sites, .python_pth_name)
  paths[file.exists(paths)]
}

#' @keywords internal
#' @noRd
pth_target <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }
  lines <- readLines(path, warn = FALSE)
  if (length(lines) < 2L || !identical(lines[[1L]], .python_pth_marker)) {
    return(NA_character_)
  }
  lines[[2L]]
}

#' @keywords internal
#' @noRd
remove_managed_python_pth <- function() {
  paths <- managed_python_pth_files()
  for (path in paths) {
    if (!is.na(pth_target(path))) {
      unlink(path, force = TRUE)
    }
  }
  invisible(paths)
}
