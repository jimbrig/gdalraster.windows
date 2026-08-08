#' Build a self-contained gdalraster package
#'
#' Compiles `gdalraster` against the managed GDAL SDK, vendors the bundle's
#' DLL dependency closure, GDAL/PROJ data, and pure-Python utilities into the
#' installed package, then records build provenance.
#'
#' @param gdal_home Installed GDAL build runtime.
#' @param lib Destination library. The default is an isolated package-managed
#'   library.
#' @param user_lib Install into `.libPaths()[1]`. This is destructive when an
#'   existing `gdalraster` is installed there and requires `force = TRUE` in
#'   non-interactive sessions.
#' @param source_tarball Optional local `gdalraster` source tarball.
#' @param repo Upstream source repository.
#' @param ref Git reference used for the source archive.
#' @param upgrade Install missing R dependencies before compiling.
#' @param repos CRAN-like repositories used when `upgrade = TRUE`.
#' @param force Replace an existing `gdalraster` package.
#' @param enable_python Provision the managed embedded-Python `.pth` file after
#'   installation when possible.
#'
#' @return Invisibly, the destination library.
#' @export
gdal_build_gdalraster <- function(
  gdal_home = default_gdal_home(),
  lib = NULL,
  user_lib = FALSE,
  source_tarball = NULL,
  repo = .gdalraster_repo,
  ref = "HEAD",
  upgrade = FALSE,
  repos = getOption("repos"),
  force = FALSE,
  enable_python = TRUE
) {
  abort_if_not_windows()
  abort_if_no_build_tools()
  check_flag(user_lib)
  check_flag(upgrade)
  check_flag(force)
  check_flag(enable_python)
  check_optional_string(lib)
  check_optional_string(source_tarball)
  check_string(repo)
  check_string(ref)

  gdal_home <- normalizePath(gdal_home, winslash = "/", mustWork = FALSE)
  validate_runtime_contract(gdal_home)
  bundle <- installed_bundle_manifest(gdal_home)
  if (is.null(bundle)) {
    cli::cli_abort(
      c(
        "The GDAL runtime has no provenance manifest.",
        "i" = "Reinstall it with {.fn gdal_install_runtime}."
      ),
      call = rlang::caller_env()
    )
  }

  lib <- resolve_gdalraster_lib(lib = lib, user_lib = user_lib)
  package_dir <- file.path(lib, "gdalraster")
  if ("gdalraster" %in% loadedNamespaces()) {
    cli::cli_abort(
      c(
        "Cannot replace {.pkg gdalraster} while it is loaded.",
        "i" = "Restart R, load only {.pkg gdalraster.windows}, and retry."
      ),
      call = rlang::caller_env()
    )
  }
  if (dir.exists(package_dir) && !isTRUE(force)) {
    if (rlang::is_interactive()) {
      replace <- utils::askYesNo(
        paste0("Replace the existing gdalraster package in ", lib, "?"),
        default = FALSE
      )
      if (!isTRUE(replace)) {
        cli::cli_abort("Build cancelled.", call = rlang::caller_env())
      }
    } else {
      cli::cli_abort(
        c(
          "{.pkg gdalraster} is already installed at {.path {package_dir}}.",
          "i" = "Set {.code force = TRUE} to replace it."
        ),
        call = rlang::caller_env()
      )
    }
  }

  tarball <- resolve_gdalraster_source(
    source_tarball = source_tarball,
    repo = repo,
    ref = ref
  )
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)

  if (isTRUE(upgrade)) {
    install_source_dependencies(tarball, lib = lib, repos = repos)
  }

  stage_lib <- tempfile(".gdalraster-stage-", tmpdir = dirname(lib))
  dir.create(stage_lib, recursive = TRUE, showWarnings = FALSE)
  withr::defer(unlink(stage_lib, recursive = TRUE, force = TRUE))

  makevars <- c(
    GDAL_HOME = gdal_home,
    PKG_CPPFLAGS = paste0("-I\"", file.path(gdal_home, "include"), "\""),
    PKG_LIBS = paste0(
      "-L\"", file.path(gdal_home, "lib"),
      "\" -lgdal -Wl,--allow-multiple-definition"
    )
  )
  build_env <- c(
    PATH = paste(gdal_bin_dir(gdal_home), Sys.getenv("PATH"), sep = .Platform$path.sep),
    GDAL_DATA = gdal_share_gdal_dir(gdal_home),
    PROJ_LIB = gdal_share_proj_dir(gdal_home),
    PROJ_DATA = gdal_share_proj_dir(gdal_home)
  )

  cli::cli_alert_info("Building {.pkg gdalraster} against {.val {manifest_value(bundle, 'Bundle-Tag')}}.")
  rlang::try_fetch(
    withr::with_libpaths(
      new = c(lib, .libPaths()),
      action = "replace",
      code = withr::with_makevars(
        new = makevars,
        assignment = "=",
        code = withr::with_envvar(
          new = build_env,
          code = utils::install.packages(
            tarball,
            repos = NULL,
            type = "source",
            lib = stage_lib,
            INSTALL_opts = "--no-test-load"
          )
        )
      )
    ),
    error = function(cnd) {
      cli::cli_abort(
        "Failed to build {.pkg gdalraster}.",
        parent = cnd,
        call = rlang::caller_env()
      )
    }
  )

  staged_package <- file.path(stage_lib, "gdalraster")
  if (!dir.exists(staged_package)) {
    cli::cli_abort(
      "The source build did not produce an installed {.pkg gdalraster} package.",
      call = rlang::caller_env()
    )
  }

  vendor_gdalraster(staged_package, gdal_home)
  write_manifest(
    list(
      `Bundle-Tag` = manifest_value(bundle, "Bundle-Tag"),
      `GDAL-Version` = manifest_value(bundle, "GDAL-Version"),
      `Built-At` = format(Sys.time(), tz = "UTC", usetz = TRUE),
      `R-Version` = as.character(getRversion()),
      Platform = R.version$platform,
      Compiler = R.version$compiler,
      `Builder-Version` = pkg_version()
    ),
    build_manifest_path(staged_package)
  )

  replace_package_tree(staged_package, package_dir)
  if (isTRUE(enable_python)) {
    gdal_enable_python(lib = lib, quiet = TRUE)
  }

  cli::cli_alert_success("Installed self-contained {.pkg gdalraster} at {.path {package_dir}}.")
  invisible(lib)
}

#' @keywords internal
#' @noRd
resolve_gdalraster_lib <- function(lib = NULL, user_lib = FALSE) {
  if (isTRUE(user_lib)) {
    return(normalizePath(.libPaths()[[1L]], winslash = "/", mustWork = FALSE))
  }
  lib <- if (is.null(lib)) default_gdalraster_lib() else lib
  normalizePath(lib, winslash = "/", mustWork = FALSE)
}

#' @keywords internal
#' @noRd
resolve_gdalraster_source <- function(source_tarball, repo, ref) {
  if (!is.null(source_tarball)) {
    abort_if_missing_file(source_tarball, "source_tarball")
    return(normalizePath(source_tarball, winslash = "/", mustWork = TRUE))
  }

  destination <- tempfile("gdalraster-", fileext = ".tar.gz")
  request <- httr2::request(paste0("https://codeload.github.com/", repo, "/tar.gz/", ref))
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
install_source_dependencies <- function(tarball, lib, repos) {
  members <- utils::untar(tarball, list = TRUE)
  description <- members[grepl("(^|/)DESCRIPTION$", members)]
  if (length(description) < 1L) {
    cli::cli_abort("The source archive has no {.file DESCRIPTION} file.")
  }

  extract <- tempfile("gdalraster-description-")
  dir.create(extract, recursive = TRUE, showWarnings = FALSE)
  withr::defer(unlink(extract, recursive = TRUE, force = TRUE))
  utils::untar(tarball, files = description[[1L]], exdir = extract)
  dcf <- read.dcf(file.path(extract, description[[1L]]))
  fields <- intersect(c("Depends", "Imports", "LinkingTo"), colnames(dcf))
  specifications <- unlist(strsplit(
    paste(dcf[1L, fields], collapse = ","),
    ",",
    fixed = TRUE
  ))
  packages <- trimws(sub("\\s*\\(.*\\)\\s*$", "", specifications))
  packages <- unique(packages[nzchar(packages) & packages != "R"])
  installed <- rownames(utils::installed.packages())
  missing <- setdiff(packages, installed)
  if (length(missing) > 0L) {
    utils::install.packages(missing, repos = repos, lib = lib, dependencies = TRUE)
  }
  invisible(missing)
}

#' @keywords internal
#' @noRd
validate_runtime_contract <- function(gdal_home) {
  required_dirs <- c(
    file.path(gdal_home, "bin"),
    file.path(gdal_home, "include"),
    file.path(gdal_home, "lib"),
    file.path(gdal_home, "share", "gdal"),
    file.path(gdal_home, "share", "proj"),
    file.path(gdal_home, "python", "osgeo_utils")
  )
  missing <- required_dirs[!dir.exists(required_dirs)]
  if (length(gdal_dll_candidates(gdal_home)) < 1L || length(missing) > 0L) {
    cli::cli_abort(
      c(
        "The GDAL runtime bundle is incomplete.",
        "x" = "Missing: {paste(missing, collapse = ', ')}",
        "i" = "Reinstall it with {.fn gdal_install_runtime}."
      ),
      call = rlang::caller_env()
    )
  }
  invisible(TRUE)
}

#' @keywords internal
#' @noRd
vendor_gdalraster <- function(package_dir, gdal_home) {
  dlls <- list.files(
    gdal_bin_dir(gdal_home),
    pattern = "\\.dll$",
    ignore.case = TRUE,
    full.names = TRUE
  )
  if (length(dlls) < 1L) {
    cli::cli_abort("The runtime bundle contains no DLLs to vendor.")
  }
  dll_destination <- file.path(package_dir, "libs", "x64")
  dir.create(dll_destination, recursive = TRUE, showWarnings = FALSE)
  copied <- file.copy(dlls, dll_destination, overwrite = TRUE, copy.mode = TRUE)
  if (!all(copied)) {
    cli::cli_abort("Failed to vendor the complete GDAL DLL closure.")
  }

  trees <- c(
    gdal = gdal_share_gdal_dir(gdal_home),
    proj = gdal_share_proj_dir(gdal_home),
    python = gdal_python_dir(gdal_home)
  )
  for (name in names(trees)) {
    destination <- file.path(package_dir, name)
    unlink(destination, recursive = TRUE, force = TRUE)
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    copy_tree(trees[[name]], destination)
  }
  invisible(package_dir)
}

#' @keywords internal
#' @noRd
replace_package_tree <- function(staged_package, package_dir) {
  backup <- paste0(package_dir, ".previous-", Sys.getpid())
  unlink(backup, recursive = TRUE, force = TRUE)

  had_existing <- dir.exists(package_dir)
  if (had_existing && !isTRUE(suppressWarnings(file.rename(package_dir, backup)))) {
    cli::cli_abort(
      c(
        "Could not replace {.pkg gdalraster}; its package directory is locked.",
        "i" = "Close sessions using {.pkg gdalraster} and retry.",
        "i" = "The existing package was left unchanged."
      ),
      call = rlang::caller_env()
    )
  }

  installed <- isTRUE(suppressWarnings(file.rename(staged_package, package_dir)))
  if (!installed) {
    if (had_existing) {
      suppressWarnings(file.rename(backup, package_dir))
    }
    cli::cli_abort(
      "Could not move the staged {.pkg gdalraster} package into {.path {dirname(package_dir)}}.",
      call = rlang::caller_env()
    )
  }

  unlink(backup, recursive = TRUE, force = TRUE)
  invisible(package_dir)
}
