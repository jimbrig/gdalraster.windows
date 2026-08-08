#' Report GDAL and gdalraster installation state
#'
#' Reports bundle and build provenance, staleness, embedded-Python
#' provisioning, and common collision risks without changing the session.
#'
#' @param lib Library expected to contain the managed `gdalraster` build.
#' @param user_lib Inspect `.libPaths()[1]` instead of the isolated library.
#' @param network Query GitHub for the latest bundle release.
#' @param quiet Return state without printing it.
#'
#' @return Invisibly, a named list describing installation state.
#' @export
gdal_sitrep <- function(
  lib = NULL,
  user_lib = FALSE,
  network = rlang::is_interactive(),
  quiet = FALSE
) {
  check_flag(user_lib)
  check_flag(network)
  check_flag(quiet)
  check_optional_string(lib)

  home <- default_gdal_home()
  lib <- resolve_gdalraster_lib(lib, user_lib)
  package_dir <- file.path(lib, "gdalraster")
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
  package_python <- normalizePath(
    file.path(package_dir, "python"),
    winslash = "/",
    mustWork = FALSE
  )
  python_ready <- any(!is.na(pth_targets) & identical_paths(pth_targets, package_python))
  python_stale <- pth_files[is.na(pth_targets) | !dir.exists(pth_targets)]

  path_gdal <- path_gdal_dlls()
  loaded_gdal <- loaded_gdal_dlls()
  legacy_hook <- legacy_hook_detected()
  visible_gdalraster <- suppressWarnings(system.file(package = "gdalraster"))
  foreign_gdalraster <- nzchar(visible_gdalraster) &&
    !identical_paths(visible_gdalraster, package_dir)

  state <- list(
    gdal_home = home,
    runtime_installed = dir.exists(home) && length(gdal_dll_candidates(home)) > 0L,
    bundle_tag = manifest_value(bundle, "Bundle-Tag"),
    gdal_version = manifest_value(bundle, "GDAL-Version"),
    latest_tag = latest,
    update_available = !is.na(latest) &&
      !identical(latest, manifest_value(bundle, "Bundle-Tag")),
    lib = lib,
    package_dir = package_dir,
    gdalraster_installed = dir.exists(package_dir),
    build_tag = manifest_value(build, "Bundle-Tag"),
    build_current = build_is_current(bundle, build),
    python_ready = python_ready,
    python_pth = pth_files,
    python_stale = python_stale,
    path_gdal = path_gdal,
    loaded_gdal = loaded_gdal,
    legacy_hook = legacy_hook,
    foreign_gdalraster = foreign_gdalraster,
    visible_gdalraster = visible_gdalraster
  )

  if (!isTRUE(quiet)) {
    print_gdal_sitrep(state)
  }
  invisible(state)
}

#' @keywords internal
#' @noRd
print_gdal_sitrep <- function(state) {
  cli::cli_h2("gdalraster.windows")
  cli::cli_inform(c(
    "*" = "runtime: {if (state$runtime_installed) state$bundle_tag else 'not installed'}",
    "*" = "gdalraster: {if (state$gdalraster_installed) state$build_tag else 'not installed'}",
    "*" = "build current: {.val {state$build_current}}",
    "*" = "embedded Python: {.val {state$python_ready}}"
  ))

  warnings <- character()
  if (isTRUE(state$update_available)) {
    warnings <- c(warnings, paste0("bundle ", state$latest_tag, " is available"))
  }
  if (length(state$path_gdal) > 0L) {
    warnings <- c(warnings, "other libgdal DLLs are present on PATH")
  }
  if (length(state$loaded_gdal) > 0L) {
    warnings <- c(warnings, "a libgdal DLL is already loaded in this session")
  }
  if (isTRUE(state$legacy_hook)) {
    warnings <- c(warnings, "a legacy gdalraster.windows .Rprofile hook was detected")
  }
  if (isTRUE(state$foreign_gdalraster)) {
    warnings <- c(warnings, "a different gdalraster installation is visible on .libPaths()")
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
    cli::cli_inform(c("i" = "Run {.fn gdal_update} to rebuild against the installed bundle."))
  } else {
    cli::cli_inform(c("i" = "Run {.fn gdal_verify} for fresh-process verification."))
  }
}

#' @keywords internal
#' @noRd
identical_paths <- function(x, y) {
  tolower(normalizePath(x, winslash = "/", mustWork = FALSE)) ==
    tolower(normalizePath(y, winslash = "/", mustWork = FALSE))
}

#' @keywords internal
#' @noRd
path_gdal_dlls <- function() {
  parts <- strsplit(Sys.getenv("PATH", unset = ""), .Platform$path.sep, fixed = TRUE)[[1L]]
  parts <- unique(parts[nzchar(parts) & dir.exists(parts)])
  unique(unlist(lapply(
    parts,
    list.files,
    pattern = .gdal_dll_pattern,
    full.names = TRUE
  ), use.names = FALSE))
}

#' @keywords internal
#' @noRd
loaded_gdal_dlls <- function() {
  paths <- vapply(
    getLoadedDLLs(),
    function(dll) dll[["path"]],
    character(1)
  )
  unname(paths[grepl(.gdal_dll_pattern, basename(paths), ignore.case = TRUE)])
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
