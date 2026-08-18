#' Report GDAL and gdalraster installation state
#'
#' Reports the installed GDAL runtime, the `gdalraster` build in the active
#' library, staleness against the newest `gdal-v*` bundle, embedded-Python
#' provisioning, and session collision risks without changing the session.
#'
#' The default inspects `.libPaths()[1]`, the library used by
#' `library(gdalraster)`. Pass `lib` for a custom library, or `isolated = TRUE`
#' for the package-managed isolated library.
#'
#' @param lib Library expected to contain the managed `gdalraster` build.
#'   Defaults to `.libPaths()[1]`.
#' @param isolated Inspect the package-managed isolated library instead of
#'   `.libPaths()[1]`. Ignored when `lib` is set.
#' @param user_lib Deprecated. `user_lib = TRUE` is now the default;
#'   `user_lib = FALSE` is equivalent to `isolated = TRUE`.
#' @param network Query GitHub for the latest GDAL runtime bundle (`gdal-v*`).
#' @param quiet Return state without printing it.
#'
#' @return Invisibly, a named list describing installation state.
#' @export
gdal_sitrep <- function(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  network = rlang::is_interactive(),
  quiet = FALSE
) {
  check_flag(isolated)
  check_optional_flag(user_lib)
  check_flag(network)
  check_flag(quiet)
  check_optional_string(lib)
  if (!is.null(user_lib)) {
    isolated <- !isTRUE(user_lib)
  }

  home <- default_gdal_home()
  lib <- resolve_gdalraster_lib(lib, isolated = isolated)
  package_dir <- normalize_pkg_path(file.path(lib, "gdalraster"))
  bundle <- installed_bundle_manifest(home)
  build <- read_manifest(build_manifest_path(package_dir))
  latest <- if (isTRUE(network)) {
    tryCatch(
      resolve_release_asset(
        repo = .bundle_repo,
        tag = "latest",
        asset_pattern = .bundle_asset_pattern
      )$tag,
      error = function(cnd) NA_character_
    )
  } else {
    NA_character_
  }

  pth_files <- managed_python_pth_files()
  pth_targets <- vapply(pth_files, pth_target, character(1))
  package_python <- normalize_pkg_path(file.path(package_dir, "python"))
  python_ready <- any(!is.na(pth_targets) & identical_paths(pth_targets, package_python))
  python_stale <- pth_files[is.na(pth_targets) | !dir.exists(pth_targets)]

  path_gdal <- path_gdal_dlls(exclude = c(home, package_dir))
  loaded_gdal <- loaded_gdal_dlls()
  legacy_hook <- legacy_hook_detected()
  visible_gdalraster <- visible_gdalraster_dir()
  foreign_gdalraster <- nzchar(visible_gdalraster) &&
    !identical_paths(visible_gdalraster, package_dir)
  visible_build <- if (nzchar(visible_gdalraster)) {
    read_manifest(build_manifest_path(visible_gdalraster))
  } else {
    NULL
  }

  state <- list(
    gdal_home = home,
    runtime_installed = dir.exists(home) && length(gdal_dll_candidates(home)) > 0L,
    bundle_tag = manifest_value(bundle, "Bundle-Tag"),
    gdal_version = manifest_value(bundle, "GDAL-Version"),
    latest_tag = latest,
    update_available = !is.na(latest) &&
      !identical(latest, manifest_value(bundle, "Bundle-Tag")),
    isolated = isolated,
    lib = lib,
    package_dir = package_dir,
    gdalraster_installed = dir.exists(package_dir),
    gdalraster_version = installed_package_version(package_dir),
    build_tag = manifest_value(build, "Bundle-Tag"),
    build_current = build_is_current(bundle, build),
    python_ready = python_ready,
    python_pth = normalize_pkg_path(pth_files),
    python_stale = normalize_pkg_path(python_stale),
    path_gdal = path_gdal,
    loaded_gdal = loaded_gdal,
    legacy_hook = legacy_hook,
    foreign_gdalraster = foreign_gdalraster,
    visible_gdalraster = visible_gdalraster,
    visible_build_current = build_is_current(bundle, visible_build)
  )

  if (!isTRUE(quiet)) {
    print_gdal_sitrep(state)
  }
  invisible(state)
}

#' @keywords internal
#' @noRd
gdalraster_status_label <- function(state) {
  if (!isTRUE(state$gdalraster_installed)) {
    return("not installed")
  }
  version <- state$gdalraster_version
  if (is.na(version) || !nzchar(version)) {
    if (is.na(state$build_tag)) {
      return("installed (missing provenance)")
    }
    return("installed")
  }
  version
}

#' @keywords internal
#' @noRd
installed_package_version <- function(package_dir) {
  path <- file.path(package_dir, "DESCRIPTION")
  if (!file.exists(path)) {
    return(NA_character_)
  }

  fields <- tryCatch(
    read.dcf(path, fields = "Version"),
    error = function(cnd) NULL
  )
  if (is.null(fields) || nrow(fields) != 1L) {
    return(NA_character_)
  }
  version <- fields[1L, "Version"]
  if (is.na(version) || !nzchar(version)) {
    return(NA_character_)
  }
  unname(version)
}

#' @keywords internal
#' @noRd
print_gdal_sitrep <- function(state) {
  cli::cli_h2("gdalraster.windows")
  cli::cli_inform(c(
    "*" = "GDAL runtime: {if (state$runtime_installed) state$bundle_tag else 'not installed'}",
    "*" = "gdal_home: {.path {state$gdal_home}}",
    "*" = "gdalraster: {gdalraster_status_label(state)}",
    "*" = "library: {.path {state$lib}}",
    "*" = "build current: {.val {state$build_current}}",
    "*" = "embedded Python: {.val {state$python_ready}}"
  ))

  warnings <- character()
  if (isTRUE(state$update_available)) {
    warnings <- c(
      warnings,
      paste0("GDAL runtime ", state$latest_tag, " is available")
    )
  }
  if (length(state$loaded_gdal) > 0L) {
    warnings <- c(warnings, "a libgdal DLL is already loaded in this session")
  }
  if (isTRUE(state$legacy_hook)) {
    warnings <- c(warnings, "a legacy gdalraster.windows .Rprofile hook was detected")
  }
  if (isTRUE(state$foreign_gdalraster) && isTRUE(state$isolated)) {
    warnings <- c(
      warnings,
      paste0(
        "library(gdalraster) would load ",
        state$visible_gdalraster,
        " instead of the isolated install"
      )
    )
  } else if (isTRUE(state$foreign_gdalraster)) {
    warnings <- c(
      warnings,
      paste0(
        "library(gdalraster) currently loads ",
        state$visible_gdalraster
      )
    )
  }
  if (length(state$python_stale) > 0L) {
    warnings <- c(warnings, "a managed Python .pth file has a stale target")
  }
  if (length(warnings) > 0L) {
    cli::cli_inform(stats::setNames(as.list(warnings), rep("!", length(warnings))))
  }

  if (!isTRUE(state$runtime_installed) || !isTRUE(state$gdalraster_installed)) {
    cli::cli_inform(c("i" = "Run {.fn gdal_setup} to complete setup."))
  } else if (!isTRUE(state$build_current)) {
    cli::cli_inform(c("i" = "Run {.fn gdal_update} to rebuild against the installed GDAL runtime."))
  } else {
    cli::cli_inform(c("i" = "Run {.fn gdal_verify} for fresh-process verification."))
  }
}

#' @keywords internal
#' @noRd
identical_paths <- function(x, y) {
  tolower(normalize_pkg_path(x)) == tolower(normalize_pkg_path(y))
}

#' @keywords internal
#' @noRd
path_is_under <- function(path, root) {
  if (
    length(path) != 1L ||
      length(root) != 1L ||
      is.na(path) ||
      is.na(root) ||
      !nzchar(path) ||
      !nzchar(root)
  ) {
    return(FALSE)
  }
  path <- tolower(normalize_pkg_path(path))
  root <- tolower(normalize_pkg_path(root))
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

#' @keywords internal
#' @noRd
path_gdal_dlls <- function(exclude = character()) {
  parts <- strsplit(Sys.getenv("PATH", unset = ""), .Platform$path.sep, fixed = TRUE)[[1L]]
  parts <- unique(parts[nzchar(parts) & dir.exists(parts)])
  dlls <- unique(unlist(
    lapply(
      parts,
      list.files,
      pattern = .gdal_dll_pattern,
      full.names = TRUE
    ),
    use.names = FALSE
  ))
  dlls <- normalize_pkg_path(dlls)
  keep <- !vapply(
    dlls,
    function(dll) {
      any(vapply(exclude, function(root) path_is_under(dll, root), logical(1)))
    },
    logical(1)
  )
  unname(dlls[keep])
}

#' @keywords internal
#' @noRd
loaded_gdal_dlls <- function() {
  paths <- vapply(
    getLoadedDLLs(),
    function(dll) dll[["path"]],
    character(1)
  )
  normalize_pkg_path(
    unname(paths[grepl(.gdal_dll_pattern, basename(paths), ignore.case = TRUE)])
  )
}

#' @keywords internal
#' @noRd
visible_gdalraster_dir <- function() {
  path <- suppressWarnings(system.file(package = "gdalraster"))
  if (!nzchar(path)) {
    return("")
  }
  normalize_pkg_path(path)
}

#' @keywords internal
#' @noRd
legacy_hook_detected <- function(rprofile = "~/.Rprofile") {
  path <- path.expand(rprofile)
  if (!file.exists(path)) {
    return(FALSE)
  }
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  grepl("gdalraster.windows hook|load_gdal_dll|ensure_gdal_runtime", text)
}
