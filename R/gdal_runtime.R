#' Resolve active GDAL home path
#'
#' Returns the currently configured GDAL runtime home used by this package.
#'
#' Resolution order:
#' 1) `options(gdalraster.windows.gdal_home = "...")`
#' 2) `GDALRASTER_WINDOWS_GDAL_HOME` environment variable
#' 3) package-managed user data directory (`tools::R_user_dir()`)
#'
#' @return A single string path.
#' @export
gdal_home <- function() {
  default_gdal_home()
}

#' Configure GDAL home for current session
#'
#' Sets GDAL home for this session using either an R option or environment
#' variable. This does not write to user profile files.
#'
#' @param path GDAL home directory path.
#' @param mode Either `"option"` or `"env"`.
#'
#' @return Invisibly returns the normalized GDAL home path.
#' @export
configure_gdal_home <- function(path, mode = c("option", "env")) {
  abort_if_not_windows()

  mode <- match.arg(mode)
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    cli::cli_abort("{.arg path} must be a single non-empty string.")
  }

  path <- normalizePath(path, winslash = "/", mustWork = FALSE)

  if (identical(mode, "option")) {
    options(gdalraster.windows.gdal_home = path)
  } else {
    Sys.setenv(GDALRASTER_WINDOWS_GDAL_HOME = path)
  }

  invisible(path)
}

#' Install precompiled GDAL runtime
#'
#' Installs the GDAL runtime into `gdal_home` from one of:
#'
#' - `local_zip` (highest precedence),
#' - GitHub release asset lookup/download,
#' - `fallback_zip` when release lookup/download fails.
#'
#' The selected zip must contain a GDAL root with `bin/libgdal-*.dll`.
#'
#' @section Offline / air-gapped installation:
#' On machines without network access, download the release asset manually
#' from <https://github.com/jimbrig/gdalraster.windows/releases>, transfer it
#' to the target machine, and install directly:
#'
#' ```r
#' gdalraster.windows::install_gdal_runtime(
#'   local_zip = "C:/Downloads/gdal-ucrt64-v3.13.1-windows-x64.zip"
#' )
#' ```
#'
#' Note that no fallback zip is shipped with the package (a full runtime
#' bundle is too large to vendor), so the fallback path only applies when you
#' provide a `fallback_zip` yourself.
#'
#' @param repo GitHub repo slug, e.g. `"jimbrig/gdalraster.windows"`.
#' @param tag Release tag or `"latest"`.
#' @param asset_pattern Regex used to select the release asset.
#' @param gdal_home Destination GDAL home directory.
#' @param overwrite Whether to replace existing `gdal_home`.
#' @param local_zip Optional local GDAL runtime zip to install directly.
#' @param fallback_zip Optional fallback zip path used when release download
#'   fails. When `NULL` (default), a vendored zip at
#'   `inst/extdata/gdal-ucrt64-fallback.zip` is used if present; none ships
#'   with the package, so by default no fallback is attempted.
#'
#' @return Invisibly returns installed GDAL home path.
#' @export
install_gdal_runtime <- function(
  repo = "jimbrig/gdalraster.windows",
  tag = "latest",
  asset_pattern = "gdal-(bundle|ucrt64)-.*\\.zip$",
  gdal_home = default_gdal_home(),
  overwrite = FALSE,
  local_zip = NULL,
  fallback_zip = NULL
) {
  abort_if_not_windows()

  if (!is.character(asset_pattern) || length(asset_pattern) != 1L || !nzchar(asset_pattern)) {
    cli::cli_abort("{.arg asset_pattern} must be a single non-empty regex string.")
  }

  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    cli::cli_abort("{.arg overwrite} must be TRUE or FALSE.")
  }

  if (is.null(fallback_zip)) {
    fallback_zip <- packaged_fallback_zip()
  }

  if (!is.null(local_zip) && (!is.character(local_zip) || length(local_zip) != 1L || !nzchar(local_zip))) {
    cli::cli_abort("{.arg local_zip} must be NULL or a single non-empty path.")
  }

  if (!is.null(fallback_zip) && (!is.character(fallback_zip) || length(fallback_zip) != 1L || !nzchar(fallback_zip))) {
    cli::cli_abort("{.arg fallback_zip} must be NULL or a single non-empty path.")
  }

  gdal_home <- normalizePath(gdal_home, winslash = "/", mustWork = FALSE)
  tmp_zip <- tempfile(pattern = "gdal-runtime-", fileext = ".zip")
  tmp_dir <- tempfile(pattern = "gdal-runtime-extract-")
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)

  zip_path <- NULL
  if (!is.null(local_zip)) {
    local_zip <- normalizePath(local_zip, winslash = "/", mustWork = FALSE)
    abort_if_missing_file(local_zip, "local_zip", call = rlang::caller_env())
    cli::cli_alert_info("using local runtime zip {.path {local_zip}}")
    zip_path <- local_zip
  } else {
    zip_path <- rlang::try_fetch(
      {
        asset <- resolve_release_asset(repo = repo, tag = tag, asset_pattern = asset_pattern)
        cli::cli_alert_info(
          "downloading gdal runtime asset {.val {asset$name}} from {.val {repo}} ({.val {asset$tag}})"
        )

        req <- httr2::request(asset$url)
        req <- httr2::req_user_agent(req, paste0(pkg_name(), "/", pkg_version()))
        req <- httr2::req_error(req, is_error = function(resp) httr2::resp_status(resp) >= 400L)
        resp <- httr2::req_perform(req)
        writeBin(httr2::resp_body_raw(resp), con = tmp_zip)
        tmp_zip
      },
      error = function(cnd) {
        fallback_exists <- !is.null(fallback_zip) && file.exists(fallback_zip)
        if (!fallback_exists) {
          cli::cli_abort(
            c(
              "Failed to download GDAL runtime from GitHub release and no local fallback is available.",
              "x" = "{conditionMessage(cnd)}",
              "i" = "To install offline, download the release asset from {.url https://github.com/{repo}/releases}",
              "i" = "then install it directly: {.code install_gdal_runtime(local_zip = \"path/to/asset.zip\")}"
            ),
            parent = cnd,
            call = rlang::caller_env()
          )
        }

        cli::cli_alert_warning(
          "release download failed; using fallback runtime zip {.path {fallback_zip}}"
        )
        normalizePath(fallback_zip, winslash = "/", mustWork = TRUE)
      }
    )
  }

  utils::unzip(zip_path, exdir = tmp_dir)
  gdal_root <- detect_gdal_root(tmp_dir)

  if (dir.exists(gdal_home)) {
    if (!isTRUE(overwrite)) {
      cli::cli_abort(
        "{.arg gdal_home} already exists and {.arg overwrite} is FALSE: {.path {gdal_home}}"
      )
    }
    unlink(gdal_home, recursive = TRUE, force = TRUE)
  }

  dir.create(gdal_home, recursive = TRUE, showWarnings = FALSE)
  copy_tree(gdal_root, gdal_home)

  cli::cli_alert_success("installed gdal runtime to {.path {gdal_home}}")
  invisible(gdal_home)
}

#' Activate GDAL runtime for current R session
#'
#' Prepends runtime paths, sets GDAL/PROJ env vars, and preloads GDAL DLL.
#'
#' When the runtime bundle contains a `python/` directory (pure-python
#' `osgeo_utils` package from GDAL's `gdal-utils` distribution), it is
#' prepended to `PYTHONPATH` so GDAL algorithms that embed Python at runtime
#' (e.g. `gdal driver gpkg validate`) can import it. This is session-scoped
#' and does not modify machine or user environment variables.
#'
#' @param gdal_home GDAL home directory.
#' @param preload Whether to preload `libgdal-*.dll`.
#' @param quiet Suppress informational CLI output.
#'
#' @return Invisibly returns a list with configured paths.
#' @export
activate_gdal_runtime <- function(
  gdal_home = default_gdal_home(),
  preload = TRUE,
  quiet = FALSE
) {
  abort_if_not_windows()

  gdal_home <- normalizePath(gdal_home, winslash = "/", mustWork = FALSE)
  abort_if_missing_dir(gdal_home, "gdal_home")

  bin_dir <- gdal_bin_dir(gdal_home)
  abort_if_missing_dir(bin_dir, "gdal_home/bin")

  dll_path <- gdal_dll_path(gdal_home)
  abort_if_missing_file(dll_path, "gdal_home/bin/libgdal-*.dll")

  path_sep <- .Platform$path.sep
  current_path <- Sys.getenv("PATH", unset = "")
  path_parts <- strsplit(current_path, split = path_sep, fixed = TRUE)[[1]]
  path_parts <- path_parts[nzchar(path_parts)]

  if (!bin_dir %in% path_parts) {
    Sys.setenv(PATH = paste(c(bin_dir, path_parts), collapse = path_sep))
  }

  gdal_data <- gdal_share_gdal_dir(gdal_home)
  proj_data <- gdal_share_proj_dir(gdal_home)
  python_dir <- gdal_python_dir(gdal_home)

  if (dir.exists(gdal_data)) {
    Sys.setenv(GDAL_DATA = gdal_data)
  }
  if (dir.exists(proj_data)) {
    Sys.setenv(PROJ_LIB = proj_data)
    Sys.setenv(PROJ_DATA = proj_data)
  }

  # expose bundled pure-python osgeo_utils to GDAL's embedded python.
  # PYTHONPATH is read at Py_Initialize(), which libgdal triggers lazily on
  # first use of an embedded-python algorithm, so setting it here is early
  # enough. session-scoped only; never persisted to user/machine env.
  if (dir.exists(python_dir)) {
    py_parts <- strsplit(Sys.getenv("PYTHONPATH", unset = ""), path_sep, fixed = TRUE)[[1]]
    py_parts <- py_parts[nzchar(py_parts)]
    if (!python_dir %in% py_parts) {
      Sys.setenv(PYTHONPATH = paste(c(python_dir, py_parts), collapse = path_sep))
    }
  }

  if (isTRUE(preload)) {
    try(dyn.load(dll_path, local = FALSE, now = TRUE), silent = TRUE)
  }

  if (!isTRUE(quiet)) {
    cli::cli_alert_success("gdal runtime activated from {.path {gdal_home}}")
  }

  invisible(
    list(
      gdal_home = gdal_home,
      gdal_bin = bin_dir,
      gdal_dll = dll_path,
      gdal_data = if (dir.exists(gdal_data)) gdal_data else NA_character_,
      proj_data = if (dir.exists(proj_data)) proj_data else NA_character_,
      gdal_python = if (dir.exists(python_dir)) python_dir else NA_character_
    )
  )
}

#' Load GDAL DLL from runtime bundle
#'
#' Convenience wrapper over [activate_gdal_runtime()] that ensures the GDAL
#' runtime is activated and the main GDAL DLL is preloaded in the current
#' session.
#'
#' @param gdal_home GDAL home directory.
#' @param quiet Suppress informational CLI output.
#'
#' @return Invisibly returns activation metadata.
#' @export
load_gdal_dll <- function(gdal_home = default_gdal_home(), quiet = FALSE) {
  activate_gdal_runtime(gdal_home = gdal_home, preload = TRUE, quiet = quiet)
}

#' Install gdalraster from source against bundled GDAL
#'
#' Downloads or uses a local gdalraster source tarball and installs it from
#' source into a dedicated library path (default) so existing user libraries
#' are not overwritten.
#'
#' @param gdal_home GDAL home directory used for compile/link flags.
#' @param lib Destination library path for installing gdalraster.
#' @param source_tarball Optional local path to `gdalraster_*.tar.gz`.
#' @param repo Source GitHub repo slug for gdalraster.
#' @param ref Git ref (branch, tag, commit) used when downloading from GitHub.
#' @param upgrade Whether to allow dependency upgrades during install.
#' @param repos CRAN-like repositories passed to [utils::install.packages()].
#'
#' @return Invisibly returns installed library path.
#' @export
install_gdalraster <- function(
  gdal_home = default_gdal_home(),
  lib = default_gdalraster_lib(),
  source_tarball = NULL,
  repo = "firelab/gdalraster",
  ref = "HEAD",
  upgrade = FALSE,
  repos = getOption("repos")
) {
  abort_if_not_windows()
  activate_gdal_runtime(gdal_home = gdal_home, preload = TRUE, quiet = TRUE)

  if (!is.character(lib) || length(lib) != 1L || !nzchar(lib)) {
    cli::cli_abort(
      "{.arg lib} must be a single non-empty path.",
      call = rlang::caller_env()
    )
  }

  if (!is.null(source_tarball)) {
    if (!is.character(source_tarball) || length(source_tarball) != 1L || !nzchar(source_tarball)) {
      cli::cli_abort(
        "{.arg source_tarball} must be NULL or a single file path.",
        call = rlang::caller_env()
      )
    }
    abort_if_missing_file(source_tarball, "source_tarball", call = rlang::caller_env())
    tarball <- normalizePath(source_tarball, winslash = "/", mustWork = TRUE)
  } else {
    if (!is.character(repo) || length(repo) != 1L || !nzchar(repo)) {
      cli::cli_abort(
        "{.arg repo} must be a single non-empty string like {.val 'owner/name'}.",
        call = rlang::caller_env()
      )
    }
    if (!is.character(ref) || length(ref) != 1L || !nzchar(ref)) {
      cli::cli_abort(
        "{.arg ref} must be a single non-empty git ref.",
        call = rlang::caller_env()
      )
    }

    tarball <- tempfile(pattern = "gdalraster-", fileext = ".tar.gz")
    src_url <- paste0("https://codeload.github.com/", repo, "/tar.gz/", ref)
    req <- httr2::request(src_url)
    req <- httr2::req_user_agent(req, paste0(pkg_name(), "/", pkg_version()))
    req <- httr2::req_error(req, is_error = function(resp) httr2::resp_status(resp) >= 400L)
    resp <- httr2::req_perform(req)
    writeBin(httr2::resp_body_raw(resp), con = tarball)
  }

  lib <- normalizePath(lib, winslash = "/", mustWork = FALSE)
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)

  gdal_home <- normalizePath(gdal_home, winslash = "/", mustWork = FALSE)
  makevars <- c(
    GDAL_HOME = gdal_home,
    PKG_CPPFLAGS = paste0("-I\"", file.path(gdal_home, "include"), "\""),
    PKG_LIBS = paste0("-L\"", file.path(gdal_home, "lib"), "\" -lgdal -Wl,--allow-multiple-definition")
  )

  path_sep <- .Platform$path.sep
  old_path <- Sys.getenv("PATH", unset = "")
  runtime_path <- paste(c(gdal_bin_dir(gdal_home), old_path), collapse = path_sep)
  env_vars <- c(
    PATH = runtime_path,
    GDAL_DATA = gdal_share_gdal_dir(gdal_home),
    PROJ_LIB = gdal_share_proj_dir(gdal_home),
    PROJ_DATA = gdal_share_proj_dir(gdal_home)
  )

  cli::cli_alert_info("installing {.pkg gdalraster} from source into {.path {lib}}")
  rlang::try_fetch(
    withr::with_makevars(new = makevars, assignment = "=", {
      withr::with_envvar(env_vars, {
        utils::install.packages(
          pkgs = tarball,
          repos = repos,
          type = "source",
          lib = lib,
          INSTALL_opts = c("--no-test-load"),
          dependencies = isTRUE(upgrade)
        )
      })
    }),
    error = function(cnd) {
      cli::cli_abort(
        c(
          "Failed to install {.pkg gdalraster} from source.",
          "x" = "{conditionMessage(cnd)}"
        ),
        parent = cnd,
        call = rlang::caller_env()
      )
    }
  )

  if (!dir.exists(file.path(lib, "gdalraster"))) {
    cli::cli_abort(
      c(
        "gdalraster source install did not produce an installed package.",
        "i" = "Library path: {.path {lib}}"
      ),
      call = rlang::caller_env()
    )
  }

  cli::cli_alert_success("installed {.pkg gdalraster} to {.path {lib}}")
  invisible(lib)
}

#' Load gdalraster using bundled GDAL runtime
#'
#' Activates bundled GDAL runtime, prepends `lib` to `.libPaths()`, and attaches
#' gdalraster for use in the current R session.
#'
#' @param lib Library path containing the gdalraster source install.
#' @param gdal_home GDAL home directory.
#' @param quiet Suppress informational CLI output.
#'
#' @return Invisibly returns TRUE if gdalraster was attached.
#' @export
load_gdalraster <- function(
  lib = default_gdalraster_lib(),
  gdal_home = default_gdal_home(),
  quiet = FALSE
) {
  abort_if_not_windows()
  activate_gdal_runtime(gdal_home = gdal_home, preload = TRUE, quiet = quiet)

  lib <- normalizePath(lib, winslash = "/", mustWork = FALSE)
  abort_if_missing_dir(lib, "lib", call = rlang::caller_env())

  if (!dir.exists(file.path(lib, "gdalraster"))) {
    cli::cli_abort(
      c(
        "No {.pkg gdalraster} install found in {.arg lib}.",
        "i" = "Run {.fn gdalraster.windows::install_gdalraster} first."
      ),
      call = rlang::caller_env()
    )
  }

  .libPaths(c(lib, .libPaths()))
  base::library("gdalraster", character.only = TRUE, lib.loc = lib)
  invisible(TRUE)
}

#' Verify gdalraster algorithm API availability
#'
#' Attempts to load `gdalraster` and checks the global algorithm registry.
#'
#' @param lib.loc Optional library location used for loading `gdalraster`.
#' @param activate_runtime Whether to run [activate_gdal_runtime()] first.
#' @param gdal_home GDAL home used when `activate_runtime = TRUE`.
#' @param quiet If `TRUE`, suppress sitrep CLI output.
#'
#' @return `TRUE` when algorithm API is available, otherwise `FALSE`.
#' @export
verify_gdalraster_runtime <- function(
  lib.loc = NULL,
  activate_runtime = TRUE,
  gdal_home = default_gdal_home(),
  quiet = FALSE
) {
  abort_if_not_windows()

  if (isTRUE(activate_runtime)) {
    activate_gdal_runtime(gdal_home = gdal_home, preload = TRUE, quiet = TRUE)
  }

  if (!has_gdalraster_namespace()) {
    if (!isTRUE(quiet)) {
      cli::cli_alert_warning("{.pkg gdalraster} is not installed.")
      cli::cli_inform("Run {.fn gdalraster.windows::install_gdalraster} first.")
    }
    return(FALSE)
  }

  ok <- rlang::try_fetch(
    {
      suppressMessages(base::library("gdalraster", character.only = TRUE, lib.loc = lib.loc))
      alg_names <- gdalraster::gdal_global_reg_names()
      version <- gdalraster::gdal_version()[[1]]
      list(ok = length(alg_names) > 0L, version = version, count = length(alg_names))
    },
    error = function(cnd) {
      if (!isTRUE(quiet)) {
        cli::cli_alert_danger("gdalraster verification failed: {conditionMessage(cnd)}")
      }
      list(ok = FALSE, version = NA_character_, count = 0L)
    }
  )

  if (!isTRUE(quiet)) {
    if (isTRUE(ok$ok)) {
      cli::cli_alert_success("gdalraster is ready ({.val {ok$version}})")
      cli::cli_inform(
        c(
          "i" = "algorithm registry entries: {.val {ok$count}}",
          "i" = "runtime home: {.path {normalizePath(gdal_home, winslash = '/', mustWork = FALSE)}}"
        )
      )
    } else {
      cli::cli_alert_warning("gdalraster loaded, but algorithm API is not available.")
      cli::cli_inform(
        c(
          "i" = "gdal version: {.val {ok$version}}",
          "i" = "algorithm registry entries: {.val {ok$count}}"
        )
      )
    }
  }

  isTRUE(ok$ok)
}

#' @keywords internal
#' @noRd
has_gdalraster_namespace <- function() {
  requireNamespace("gdalraster", quietly = TRUE)
}

#' @keywords internal
#' @noRd
detect_gdal_root <- function(extract_dir) {
  dll_candidates <- list.files(
    path = extract_dir,
    pattern = "^libgdal-[0-9]+\\.dll$",
    all.files = TRUE,
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(dll_candidates) < 1L) {
    cli::cli_abort(
      "Could not find {.file libgdal-*.dll} in extracted release asset."
    )
  }

  normalizePath(dirname(dirname(dll_candidates[[1]])), winslash = "/", mustWork = TRUE)
}

#' @keywords internal
#' @noRd
copy_tree <- function(from, to) {
  entries <- list.files(
    path = from,
    all.files = TRUE,
    no.. = TRUE,
    recursive = TRUE,
    include.dirs = TRUE
  )

  for (entry in entries) {
    src <- file.path(from, entry)
    dst <- file.path(to, entry)
    if (dir.exists(src)) {
      dir.create(dst, recursive = TRUE, showWarnings = FALSE)
    } else {
      dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
      ok <- file.copy(from = src, to = dst, overwrite = TRUE, copy.mode = TRUE)
      if (!isTRUE(ok)) {
        cli::cli_abort("Failed to copy {.path {src}} to {.path {dst}}.")
      }
    }
  }
}
