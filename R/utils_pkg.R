#  ------------------------------------------------------------------------
#
# Title : package utilities
#    By : Jimmy Briggs
#  Date : 2026-05-10
#
#  ------------------------------------------------------------------------

# meta ------------------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
pkg_name <- function() {
  "gdalraster.windows"
}

#' @keywords internal
#' @noRd
#' @importFrom utils packageVersion
pkg_version <- function() {
  as.character(utils::packageVersion(pkg_name()))
}

# paths -----------------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
default_gdal_home <- function() {
  opt_home <- getOption("gdalraster.windows.gdal_home", default = "")
  if (is.character(opt_home) && length(opt_home) == 1L && nzchar(opt_home)) {
    return(normalizePath(opt_home, winslash = "/", mustWork = FALSE))
  }

  env_home <- Sys.getenv("GDALRASTER_WINDOWS_GDAL_HOME", unset = "")
  if (nzchar(env_home)) {
    return(normalizePath(env_home, winslash = "/", mustWork = FALSE))
  }

  file.path(tools::R_user_dir(pkg_name(), which = "data"), "gdal")
}

#' @keywords internal
#' @noRd
gdal_bin_dir <- function(gdal_home = default_gdal_home()) {
  file.path(gdal_home, "bin")
}

#' @keywords internal
#' @noRd
gdal_share_gdal_dir <- function(gdal_home = default_gdal_home()) {
  file.path(gdal_home, "share", "gdal")
}

#' @keywords internal
#' @noRd
gdal_share_proj_dir <- function(gdal_home = default_gdal_home()) {
  file.path(gdal_home, "share", "proj")
}

#' @keywords internal
#' @noRd
gdal_dll_candidates <- function(gdal_home = default_gdal_home()) {
  bin_dir <- gdal_bin_dir(gdal_home)
  if (!dir.exists(bin_dir)) {
    return(character())
  }

  list.files(
    path = bin_dir,
    pattern = "^libgdal-[0-9]+\\.dll$",
    full.names = TRUE
  )
}

#' @keywords internal
#' @noRd
gdal_dll_path <- function(gdal_home = default_gdal_home()) {
  dlls <- gdal_dll_candidates(gdal_home = gdal_home)
  if (length(dlls) < 1L) {
    return(file.path(gdal_bin_dir(gdal_home), "libgdal-39.dll"))
  }
  dlls[[1]]
}

#' @keywords internal
#' @noRd
default_gdalraster_lib <- function() {
  file.path(tools::R_user_dir(pkg_name(), which = "data"), "library")
}

# validation ------------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
abort_if_not_windows <- function(call = rlang::caller_env()) {
  if (.Platform$OS.type != "windows") {
    cli::cli_abort(
      "{.pkg {pkg_name()}} only supports Windows.",
      call = call
    )
  }
}

#' @keywords internal
#' @noRd
abort_if_missing_dir <- function(path, arg, call = rlang::caller_env()) {
  if (!dir.exists(path)) {
    cli::cli_abort(
      "{.arg {arg}} directory does not exist: {.path {path}}",
      call = call
    )
  }
}

#' @keywords internal
#' @noRd
abort_if_missing_file <- function(path, arg, call = rlang::caller_env()) {
  if (!file.exists(path)) {
    cli::cli_abort(
      "{.arg {arg}} file does not exist: {.path {path}}",
      call = call
    )
  }
}

# github release helpers -----------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
github_release_url <- function(repo, tag = "latest") {
  if (!is.character(repo) || length(repo) != 1L || !nzchar(repo)) {
    cli::cli_abort(
      "{.arg repo} must be a single non-empty string like {.val 'owner/name'}.",
      call = rlang::caller_env()
    )
  }
  if (!is.character(tag) || length(tag) != 1L || !nzchar(tag)) {
    cli::cli_abort(
      "{.arg tag} must be a single non-empty string.",
      call = rlang::caller_env()
    )
  }

  if (identical(tag, "latest")) {
    paste0("https://api.github.com/repos/", repo, "/releases/latest")
  } else {
    paste0("https://api.github.com/repos/", repo, "/releases/tags/", tag)
  }
}

#' @keywords internal
#' @noRd
resolve_release_asset <- function(repo, tag = "latest", asset_pattern = "\\.zip$") {
  release_req <- httr2::request(github_release_url(repo = repo, tag = tag))
  release_req <- httr2::req_user_agent(
    release_req,
    paste0(pkg_name(), "/", pkg_version())
  )
  release_req <- httr2::req_error(
    release_req,
    is_error = function(resp) httr2::resp_status(resp) >= 400L
  )
  release_resp <- httr2::req_perform(release_req)
  release_json <- httr2::resp_body_json(release_resp, simplifyVector = TRUE)

  assets <- release_json$assets
  if (is.null(assets) || length(assets) == 0L) {
    cli::cli_abort(
      "No release assets found for {.val {repo}} ({.val {tag}}).",
      call = rlang::caller_env()
    )
  }

  match_idx <- which(grepl(asset_pattern, assets$name, perl = TRUE))
  if (length(match_idx) < 1L) {
    cli::cli_abort(
      c(
        "No release asset matched {.val {asset_pattern}}.",
        "i" = "Repo: {.val {repo}}",
        "i" = "Tag: {.val {tag}}"
      ),
      call = rlang::caller_env()
    )
  }

  asset <- assets[match_idx[[1]], , drop = FALSE]
  list(
    id = asset$id[[1]],
    name = asset$name[[1]],
    url = asset$browser_download_url[[1]],
    tag = release_json$tag_name[[1]]
  )
}

# system file -----------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
pkg_sys <- function(...) {
  system.file(..., package = pkg_name())
}

#' @keywords internal
#' @noRd
# pkg_sys_config <- function(...) {
#   pkg_sys("config", ...)
# }

#' @keywords internal
#' @noRd
# pkg_sys_extdata <- function(...) {
#   pkg_sys("extdata", ...)
# }

# startup message -------------------------------------------------------------------------------------------------

#' @keywords internal
#' @noRd
pkg_startup_msg <- function() {
  paste0(pkg_name(), " v", pkg_version())
}

# environment -----------------------------------------------------------------------------------------------------

init_pkg_env <- function() {
  if (!exists(".pkg_env")) {
    return()
  }
  # config
  # .pkg_env$config <- rlang::new_environment()
}
