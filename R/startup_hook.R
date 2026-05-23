#' Build an .Rprofile hook snippet for bundled GDAL
#'
#' Returns R code that loads the bundled GDAL DLL before attaching
#' `gdalraster`, and prepends the custom `lib` path so `library(gdalraster)`
#' resolves to the source build installed by [install_gdalraster()].
#'
#' @param gdal_home GDAL home directory.
#' @param lib Library path containing the custom gdalraster install.
#'
#' @return A single string containing R code.
#' @export
gdal_rprofile_snippet <- function(
  gdal_home = default_gdal_home(),
  lib = default_gdalraster_lib()
) {
  abort_if_not_windows()

  if (!is.character(gdal_home) || length(gdal_home) != 1L || !nzchar(gdal_home)) {
    cli::cli_abort(
      "{.arg gdal_home} must be a single non-empty path.",
      call = rlang::caller_env()
    )
  }
  if (!is.character(lib) || length(lib) != 1L || !nzchar(lib)) {
    cli::cli_abort(
      "{.arg lib} must be a single non-empty path.",
      call = rlang::caller_env()
    )
  }

  gdal_home <- normalizePath(gdal_home, winslash = "/", mustWork = FALSE)
  lib <- normalizePath(lib, winslash = "/", mustWork = FALSE)

  paste(
    c(
      "if (.Platform$OS.type == \"windows\" && requireNamespace(\"gdalraster.windows\", quietly = TRUE)) {",
      paste0("  try(gdalraster.windows::load_gdal_dll(gdal_home = \"", gdal_home, "\", quiet = TRUE), silent = TRUE)"),
      paste0("  if (dir.exists(\"", lib, "\") && !(\"", lib, "\" %in% .libPaths())) {"),
      paste0("    .libPaths(c(\"", lib, "\", .libPaths()))"),
      "  }",
      "}"
    ),
    collapse = "\n"
  )
}

#' Add or update an .Rprofile hook for bundled GDAL
#'
#' Writes a managed hook block into an `.Rprofile` file. The block loads the
#' bundled GDAL DLL before package attach and prepends the custom gdalraster
#' library path.
#'
#' @param rprofile Target `.Rprofile` path.
#' @param gdal_home GDAL home directory.
#' @param lib Library path containing the custom gdalraster install.
#' @param dry_run If `TRUE`, return the updated file contents without writing.
#'
#' @return Invisibly returns the updated `.Rprofile` text.
#' @export
add_gdal_rprofile_hook <- function(
  rprofile = "~/.Rprofile",
  gdal_home = default_gdal_home(),
  lib = default_gdalraster_lib(),
  dry_run = FALSE
) {
  abort_if_not_windows()

  if (!is.character(rprofile) || length(rprofile) != 1L || !nzchar(rprofile)) {
    cli::cli_abort(
      "{.arg rprofile} must be a single non-empty path.",
      call = rlang::caller_env()
    )
  }
  if (!is.logical(dry_run) || length(dry_run) != 1L || is.na(dry_run)) {
    cli::cli_abort(
      "{.arg dry_run} must be TRUE or FALSE.",
      call = rlang::caller_env()
    )
  }

  rprofile <- path.expand(rprofile)
  dir.create(dirname(rprofile), recursive = TRUE, showWarnings = FALSE)

  start_marker <- "# >>> gdalraster.windows hook >>>"
  end_marker <- "# <<< gdalraster.windows hook <<<"
  hook <- gdal_rprofile_snippet(gdal_home = gdal_home, lib = lib)
  block <- c(start_marker, hook, end_marker)

  lines <- if (file.exists(rprofile)) readLines(rprofile, warn = FALSE) else character()
  start_idx <- match(start_marker, lines)
  end_idx <- match(end_marker, lines)

  if (xor(is.na(start_idx), is.na(end_idx))) {
    cli::cli_abort(
      "Found incomplete managed hook block in {.path {rprofile}}.",
      call = rlang::caller_env()
    )
  }
  if (!is.na(start_idx) && !is.na(end_idx) && end_idx <= start_idx) {
    cli::cli_abort(
      "Managed hook markers are out of order in {.path {rprofile}}.",
      call = rlang::caller_env()
    )
  }

  updated <- if (is.na(start_idx)) {
    if (length(lines) > 0L && nzchar(lines[[length(lines)]])) {
      c(lines, "", block)
    } else {
      c(lines, block)
    }
  } else {
    head_lines <- if (start_idx > 1L) lines[seq_len(start_idx - 1L)] else character()
    tail_lines <- if (end_idx < length(lines)) lines[seq.int(end_idx + 1L, length(lines))] else character()
    c(head_lines, block, tail_lines)
  }

  if (!isTRUE(dry_run)) {
    writeLines(updated, con = rprofile, useBytes = TRUE)
    cli::cli_alert_success("updated {.path {rprofile}} with gdal startup hook")
  }

  invisible(paste(updated, collapse = "\n"))
}
