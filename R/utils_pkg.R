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

#' Normalize package-managed paths to forward slashes
#' @keywords internal
#' @noRd
normalize_pkg_path <- function(path, mustWork = FALSE) {
  if (!is.character(path) || length(path) == 0L) {
    return(path)
  }
  vapply(
    path,
    function(item) {
      if (is.na(item) || !nzchar(item)) {
        return(item)
      }
      normalizePath(item, winslash = "/", mustWork = mustWork)
    },
    character(1),
    USE.NAMES = FALSE
  )
}

#' @keywords internal
#' @noRd
default_gdal_home <- function() {
  opt_home <- getOption("gdalraster.windows.gdal_home", default = "")
  if (is.character(opt_home) && length(opt_home) == 1L && nzchar(opt_home)) {
    return(normalize_pkg_path(opt_home))
  }

  env_home <- Sys.getenv("GDALRASTER_WINDOWS_GDAL_HOME", unset = "")
  if (nzchar(env_home)) {
    return(normalize_pkg_path(env_home))
  }

  normalize_pkg_path(file.path(tools::R_user_dir(pkg_name(), which = "data"), "gdal"))
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
gdal_python_dir <- function(gdal_home = default_gdal_home()) {
  file.path(gdal_home, "python")
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
    pattern = .gdal_dll_pattern,
    full.names = TRUE
  )
}

#' @keywords internal
#' @noRd
gdal_dll_path <- function(gdal_home = default_gdal_home()) {
  dlls <- gdal_dll_candidates(gdal_home = gdal_home)
  if (length(dlls) < 1L) {
    return(file.path(gdal_bin_dir(gdal_home), .gdal_dll_fallback))
  }
  dlls[[1]]
}

#' Unique sibling directory used to move aside runtime files that are still
#' mapped into a process and therefore cannot be deleted (only renamed)
#' @keywords internal
#' @noRd
stale_runtime_dir <- function(gdal_home) {
  file.path(
    dirname(gdal_home),
    sprintf(
      "%s%s%d-%s",
      basename(gdal_home),
      .stale_runtime_suffix,
      Sys.getpid(),
      format(Sys.time(), "%Y%m%d%H%M%OS3")
    )
  )
}

#' Best-effort deletion of stale runtime directories left by previous
#' overwrites; directories still holding mapped DLLs survive (unlink skips
#' locked files silently) and are retried on the next install
#' @keywords internal
#' @noRd
cleanup_stale_runtimes <- function(gdal_home) {
  parent <- dirname(gdal_home)
  if (!dir.exists(parent)) {
    return(invisible(character()))
  }

  entries <- list.files(parent, all.files = TRUE, no.. = TRUE)
  stale <- entries[startsWith(entries, paste0(basename(gdal_home), .stale_runtime_suffix))]
  stale <- file.path(parent, stale)
  stale <- stale[dir.exists(stale)]

  for (dir in stale) {
    unlink(dir, recursive = TRUE, force = TRUE)
  }

  invisible(stale)
}

#' @keywords internal
#' @noRd
default_gdalraster_lib <- function() {
  normalize_pkg_path(file.path(tools::R_user_dir(pkg_name(), which = "data"), "library"))
}

#' @keywords internal
#' @noRd
packaged_fallback_zip <- function() {
  path <- pkg_sys("extdata", "gdal-ucrt64-fallback.zip")
  if (!is.character(path) || !nzchar(path)) {
    return(NULL)
  }
  path
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

#' Preflight check that a source-compilation toolchain (Rtools) is available.
#' pkgbuild::has_build_tools() locates Rtools (PATH, then registry), verifies
#' the found version matches the running R, and confirms a working compile
#' environment; the result is cached for the session.
#' @keywords internal
#' @noRd
#' @importFrom pkgbuild has_build_tools
abort_if_no_build_tools <- function(call = rlang::caller_env()) {
  if (isTRUE(pkgbuild::has_build_tools())) {
    return(invisible(TRUE))
  }

  cli::cli_abort(
    c(
      "No working Windows build toolchain (Rtools) was found.",
      "x" = "{.fn gdal_build_gdalraster} compiles gdalraster from source, which requires Rtools.",
      "i" = "Install the Rtools version matching your R ({.val {as.character(getRversion())}}) from {.url https://cran.r-project.org/bin/windows/Rtools/} and restart R.",
      "i" = "Run {.code pkgbuild::check_build_tools(debug = TRUE)} for detection diagnostics."
    ),
    call = call
  )
}

#' @keywords internal
#' @noRd
check_string <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    cli::cli_abort("{.arg {arg}} must be a single non-empty string.", call = call)
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
check_optional_string <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (!is.null(x)) {
    check_string(x, arg = arg, call = call)
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
check_flag <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be {.val TRUE} or {.val FALSE}.", call = call)
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
check_optional_flag <- function(
  x,
  arg = rlang::caller_arg(x),
  call = rlang::caller_env()
) {
  if (!is.null(x)) {
    check_flag(x, arg = arg, call = call)
  }
  invisible(x)
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
    paste0("https://api.github.com/repos/", repo, "/releases?per_page=100")
  } else {
    paste0("https://api.github.com/repos/", repo, "/releases/tags/", tag)
  }
}

#' Token from the git credential store, empty string when unavailable
#' @keywords internal
#' @noRd
#' @importFrom gitcreds gitcreds_get
#' @importFrom rlang try_fetch
gitcreds_pat <- function() {
  rlang::try_fetch(
    {
      creds <- gitcreds::gitcreds_get(url = "https://github.com")
      if (is.null(creds$password)) "" else creds$password
    },
    error = function(cnd) ""
  )
}

#' Resolve a GitHub PAT: git credential store (gitcreds), then the
#' GITHUB_PAT and GITHUB_TOKEN environment variables; "" when none found
#' @keywords internal
#' @noRd
github_pat <- function() {
  pat <- gitcreds_pat()
  if (nzchar(pat)) {
    return(pat)
  }
  pat <- Sys.getenv("GITHUB_PAT", unset = "")
  if (nzchar(pat)) {
    return(pat)
  }
  Sys.getenv("GITHUB_TOKEN", unset = "")
}

#' @keywords internal
#' @noRd
#' @importFrom httr2 request req_user_agent req_auth_bearer_token req_error req_perform resp_body_json resp_status
github_api_json <- function(url, pat = github_pat()) {
  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, paste0(pkg_name(), "/", pkg_version()))
  if (is.character(pat) && length(pat) == 1L && nzchar(pat)) {
    req <- httr2::req_auth_bearer_token(req, pat)
  }
  req <- httr2::req_error(req, is_error = function(resp) httr2::resp_status(resp) >= 400L)
  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Pick the newest published non-draft, non-prerelease `gdal-v*` release
#' carrying an asset that matches `asset_pattern`.
#'
#' The repository publishes two kinds of releases: GDAL runtime bundle
#' releases (`gdal-v*` tags, with a bundle zip asset) and R package releases
#' (`v*` tags). Package releases may still carry a leftover bundle zip from
#' earlier publishing, so "latest" ignores `v*` tags even when an asset
#' matches. GitHub's `/releases/latest` pointer tracks the package releases,
#' so this scans the release list instead.
#'
#' @keywords internal
#' @noRd
select_release_asset <- function(releases, asset_pattern, call = rlang::caller_env()) {
  published_at <- vapply(
    releases,
    function(release) {
      value <- release$published_at
      if (is.null(value) || !nzchar(value)) {
        return("1970-01-01T00:00:00Z")
      }
      as.character(value)
    },
    character(1)
  )
  releases <- releases[order(published_at, decreasing = TRUE)]

  for (release in releases) {
    if (isTRUE(release$draft) || isTRUE(release$prerelease)) {
      next
    }
    tag <- release$tag_name
    if (is.null(tag) || !grepl(.bundle_tag_pattern, tag)) {
      next
    }
    for (asset in release$assets) {
      asset_name <- asset[["name"]]
      if (is.null(asset_name) || !nzchar(asset_name)) {
        next
      }
      if (grepl(asset_pattern, asset_name, perl = TRUE)) {
        return(list(
          id = asset$id,
          name = asset_name,
          url = asset$browser_download_url,
          tag = tag
        ))
      }
    }
  }

  cli::cli_abort(
    "No {.val gdal-v*} release with an asset matching {.val {asset_pattern}} was found.",
    call = call
  )
}

#' @keywords internal
#' @noRd
resolve_release_asset <- function(repo, tag = "latest", asset_pattern = "\\.zip$") {
  release_json <- github_api_json(github_release_url(repo = repo, tag = tag))

  if (identical(tag, "latest")) {
    return(select_release_asset(
      release_json,
      asset_pattern = asset_pattern,
      call = rlang::caller_env()
    ))
  }

  assets <- release_json$assets
  if (is.null(assets) || length(assets) == 0L) {
    cli::cli_abort(
      "No release assets found for {.val {repo}} ({.val {tag}}).",
      call = rlang::caller_env()
    )
  }

  asset_names <- vapply(
    assets,
    function(asset) {
      name <- asset[["name"]]
      if (is.null(name)) "" else as.character(name)
    },
    character(1)
  )
  match_idx <- which(grepl(asset_pattern, asset_names, perl = TRUE))
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

  asset <- assets[[match_idx[[1]]]]
  list(
    id = asset$id,
    name = asset$name,
    url = asset$browser_download_url,
    tag = release_json$tag_name
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

# environment -----------------------------------------------------------------------------------------------------

init_pkg_env <- function() {
  if (!exists(".pkg_env")) {
    return()
  }
  # config
  # .pkg_env$config <- rlang::new_environment()
}
