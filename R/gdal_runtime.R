#' Resolve the managed GDAL runtime directory
#'
#' Resolution order is the `gdalraster.windows.gdal_home` option, the
#' `GDALRASTER_WINDOWS_GDAL_HOME` environment variable, then the package-managed
#' user data directory. The returned path is normalized to forward slashes.
#'
#' @return A single path.
#' @export
gdal_home <- function() {
  default_gdal_home()
}

#' Install a self-contained GDAL build runtime
#'
#' Installs a release bundle used to compile [gdal_build_gdalraster()]. The
#' installed runtime is a build-time SDK; packages produced by
#' [gdal_build_gdalraster()] vendor everything needed at run time.
#'
#' The installer is idempotent. When the requested bundle tag is already
#' recorded in `MANIFEST.dcf`, installation is skipped unless `force = TRUE`.
#'
#' @param repo GitHub repository that publishes bundle releases.
#' @param tag Bundle release tag or `"latest"`.
#' @param asset_pattern Regular expression selecting a bundle zip asset.
#' @param gdal_home Destination runtime directory.
#' @param force Reinstall an existing runtime.
#' @param local_zip Optional local bundle zip. This takes precedence over a
#'   release download.
#' @param fallback_zip Optional local zip used if release resolution or download
#'   fails.
#'
#' @return Invisibly, the installed runtime directory.
#' @export
gdal_install_runtime <- function(
  repo = .bundle_repo,
  tag = "latest",
  asset_pattern = .bundle_asset_pattern,
  gdal_home = default_gdal_home(),
  force = FALSE,
  local_zip = NULL,
  fallback_zip = NULL
) {
  abort_if_not_windows()
  check_string(repo)
  check_string(tag)
  check_string(asset_pattern)
  check_flag(force)
  check_optional_string(local_zip)
  check_optional_string(fallback_zip)

  gdal_home <- normalizePath(gdal_home, winslash = "/", mustWork = FALSE)
  cleanup_stale_runtimes(gdal_home)
  installed <- installed_bundle_manifest(gdal_home)
  asset <- NULL

  if (is.null(local_zip)) {
    asset <- rlang::try_fetch(
      resolve_release_asset(repo = repo, tag = tag, asset_pattern = asset_pattern),
      error = function(cnd) {
        fallback <- if (is.null(fallback_zip)) packaged_fallback_zip() else fallback_zip
        if (is.null(fallback) || !file.exists(fallback)) {
          cli::cli_abort(
            c(
              "Failed to resolve the GDAL runtime release and no fallback is available.",
              "x" = "{conditionMessage(cnd)}",
              "i" = "Download a bundle from {.url https://github.com/{repo}/releases} and pass it with {.arg local_zip}."
            ),
            parent = cnd,
            call = rlang::caller_env()
          )
        }
        list(
          name = basename(fallback),
          tag = "fallback",
          local_path = normalizePath(fallback, winslash = "/", mustWork = TRUE)
        )
      }
    )

    if (
      !isTRUE(force) &&
        dir.exists(gdal_home) &&
        identical(manifest_value(installed, "Bundle-Tag"), asset$tag)
    ) {
      cli::cli_alert_success("GDAL runtime {.val {asset$tag}} is already installed.")
      return(invisible(gdal_home))
    }
  }

  if (
    dir.exists(gdal_home) &&
      !isTRUE(force) &&
      is.null(local_zip) &&
      identical(tag, "latest")
  ) {
    cli::cli_alert_warning(
      paste0(
        "GDAL runtime ",
        manifest_value(installed, "Bundle-Tag", "unknown"),
        " is installed; ",
        asset$tag,
        " is available. Run gdal_update() to upgrade."
      )
    )
    return(invisible(gdal_home))
  }

  if (dir.exists(gdal_home) && !isTRUE(force) && is.null(local_zip)) {
    cli::cli_abort(
      c(
        "A different or untracked GDAL runtime is installed at {.path {gdal_home}}.",
        "i" = "Run {.fn gdal_update} or set {.code force = TRUE} to replace it."
      ),
      call = rlang::caller_env()
    )
  }

  zip_path <- if (!is.null(local_zip)) {
    abort_if_missing_file(local_zip, "local_zip")
    normalizePath(local_zip, winslash = "/", mustWork = TRUE)
  } else if (!is.null(asset[["local_path"]])) {
    cli::cli_alert_warning("Release lookup failed; using {.file {asset$name}}.")
    asset$local_path
  } else {
    download_release_asset(asset, repo = repo)
  }

  extract_dir <- tempfile("gdal-runtime-extract-")
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  withr::defer(unlink(extract_dir, recursive = TRUE, force = TRUE))
  utils::unzip(zip_path, exdir = extract_dir)
  source_root <- detect_gdal_root(extract_dir)
  embedded <- read_manifest(file.path(source_root, "MANIFEST.dcf"))

  selected_tag <- manifest_value(
    embedded,
    "Bundle-Tag",
    default = if (!is.null(asset[["tag"]])) {
      asset$tag
    } else if (identical(tag, "latest")) {
      "local"
    } else {
      tag
    }
  )
  selected_asset <- if (is.null(asset[["name"]])) basename(zip_path) else asset$name

  if (
    !isTRUE(force) &&
      dir.exists(gdal_home) &&
      identical(manifest_value(installed, "Bundle-Tag"), selected_tag)
  ) {
    cli::cli_alert_success("GDAL runtime {.val {selected_tag}} is already installed.")
    return(invisible(gdal_home))
  }

  if (dir.exists(gdal_home) && !isTRUE(force)) {
    cli::cli_abort(
      c(
        "GDAL runtime {.val {manifest_value(installed, 'Bundle-Tag', 'unknown')}} is already installed.",
        "i" = "Requested bundle: {.val {selected_tag}}.",
        "i" = "Set {.code force = TRUE} to replace it."
      ),
      call = rlang::caller_env()
    )
  }

  moved_aside <- FALSE
  if (dir.exists(gdal_home)) {
    moved_aside <- remove_gdal_home(gdal_home)
  }

  dir.create(gdal_home, recursive = TRUE, showWarnings = FALSE)
  copy_tree(source_root, gdal_home)

  manifest <- if (is.null(embedded)) {
    bundle_manifest(
      tag = selected_tag,
      gdal_version = gdal_version_from_tag(selected_tag),
      asset_name = selected_asset
    )
  } else {
    embedded
  }
  manifest[["Bundle-Tag"]] <- selected_tag
  manifest[["Asset-Name"]] <- selected_asset
  manifest[["Installed-At"]] <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  manifest[["Installer-Version"]] <- pkg_version()
  write_manifest(manifest, bundle_manifest_path(gdal_home))

  cli::cli_alert_success("Installed GDAL runtime {.val {selected_tag}}.")
  if (isTRUE(moved_aside)) {
    cli::cli_alert_warning(
      "Mapped files from the previous runtime were moved aside; restart R before building."
    )
  }
  invisible(gdal_home)
}

#' @keywords internal
#' @noRd
download_release_asset <- function(asset, repo) {
  destination <- tempfile("gdal-runtime-", fileext = ".zip")
  cli::cli_alert_info(
    "Downloading {.file {asset$name}} from {.val {repo}} ({.val {asset$tag}})."
  )
  request <- httr2::request(asset$url)
  request <- httr2::req_user_agent(request, paste0(pkg_name(), "/", pkg_version()))
  request <- httr2::req_error(
    request,
    is_error = function(response) httr2::resp_status(response) >= 400L
  )
  response <- httr2::req_perform(request)
  writeBin(httr2::resp_body_raw(response), destination)
  destination
}

#' @keywords internal
#' @noRd
detect_gdal_root <- function(extract_dir) {
  dlls <- list.files(
    extract_dir,
    pattern = .gdal_dll_pattern,
    recursive = TRUE,
    full.names = TRUE
  )
  if (length(dlls) < 1L) {
    cli::cli_abort("Could not find {.file libgdal-*.dll} in the bundle.")
  }
  normalizePath(dirname(dirname(dlls[[1L]])), winslash = "/", mustWork = TRUE)
}

#' @keywords internal
#' @noRd
remove_gdal_home <- function(gdal_home, call = rlang::caller_env()) {
  cleanup_stale_runtimes(gdal_home)
  unlink(gdal_home, recursive = TRUE, force = TRUE)
  if (!dir.exists(gdal_home)) {
    return(invisible(FALSE))
  }

  stale_dir <- stale_runtime_dir(gdal_home)
  if (!move_tree_aside(gdal_home, stale_dir)) {
    cli::cli_abort(
      c(
        "Could not fully delete or move aside the runtime at {.path {gdal_home}}.",
        "x" = "One or more files are locked by another process.",
        "i" = "Close other R sessions and File Explorer windows using this directory, then retry."
      ),
      call = call
    )
  }
  invisible(TRUE)
}

#' @keywords internal
#' @noRd
move_tree_aside <- function(from, to) {
  entries <- list.files(
    from,
    all.files = TRUE,
    no.. = TRUE,
    recursive = TRUE,
    include.dirs = FALSE
  )
  ok <- TRUE
  for (entry in entries) {
    source <- file.path(from, entry)
    destination <- file.path(to, entry)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!isTRUE(suppressWarnings(file.rename(source, destination)))) {
      ok <- FALSE
    }
  }
  unlink(from, recursive = TRUE, force = TRUE)
  ok && !dir.exists(from)
}

#' @keywords internal
#' @noRd
copy_tree <- function(from, to) {
  entries <- list.files(
    from,
    all.files = TRUE,
    no.. = TRUE,
    recursive = TRUE,
    include.dirs = TRUE
  )
  for (entry in entries) {
    source <- file.path(from, entry)
    destination <- file.path(to, entry)
    if (dir.exists(source)) {
      dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    } else {
      dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      if (!isTRUE(file.copy(source, destination, overwrite = TRUE, copy.mode = TRUE))) {
        cli::cli_abort("Failed to copy {.path {source}} to {.path {destination}}.")
      }
    }
  }
  invisible(to)
}
