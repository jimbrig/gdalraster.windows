#' Set up a self-contained gdalraster installation
#'
#' Installs the GDAL build runtime when needed, builds and vendors
#' `gdalraster`, provisions embedded Python when available, and verifies the
#' result in fresh processes. The default destination is `.libPaths()[1]`.
#'
#' @param lib Destination library for `gdalraster`. Defaults to
#'   `.libPaths()[1]`.
#' @param isolated Install into the package-managed isolated library instead of
#'   `.libPaths()[1]`. Ignored when `lib` is set.
#' @param user_lib Deprecated. `user_lib = TRUE` is now the default;
#'   `user_lib = FALSE` is equivalent to `isolated = TRUE`.
#' @param update Upgrade the runtime to the requested/latest bundle and rebuild.
#' @param force Reinstall and rebuild even when provenance is current.
#' @param tag Runtime bundle release tag or `"latest"`.
#' @param local_zip Optional local runtime bundle.
#' @param fallback_zip Optional local fallback runtime bundle.
#' @param source_tarball Optional local `gdalraster` source tarball.
#' @param upgrade Install `gdalraster` R dependencies before compiling.
#' @param verify Run [gdal_verify()] after setup.
#'
#' @return Invisibly, a list describing performed actions.
#' @export
gdal_setup <- function(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  update = FALSE,
  force = FALSE,
  tag = "latest",
  local_zip = NULL,
  fallback_zip = NULL,
  source_tarball = NULL,
  upgrade = FALSE,
  verify = TRUE
) {
  abort_if_not_windows()
  check_flag(isolated)
  check_optional_flag(user_lib)
  check_flag(update)
  check_flag(force)
  check_flag(upgrade)
  check_flag(verify)
  check_string(tag)
  check_optional_string(lib)
  check_optional_string(local_zip)
  check_optional_string(fallback_zip)
  check_optional_string(source_tarball)

  lib <- resolve_gdalraster_lib(lib, isolated = isolated, user_lib = user_lib)
  before <- gdal_sitrep(lib = lib, network = FALSE, quiet = TRUE)
  install_runtime <- !before$runtime_installed || isTRUE(update) || isTRUE(force)
  build_package <- !before$gdalraster_installed ||
    !before$build_current ||
    isTRUE(update) ||
    isTRUE(force)

  cli::cli_h2("Setup plan")
  cli::cli_inform(c(
    "1" = "{if (install_runtime) 'Install or refresh' else 'Keep'} the GDAL build runtime",
    "2" = "{if (build_package) 'Build and vendor' else 'Keep'} {.pkg gdalraster}",
    "3" = "Provision embedded-Python utilities when CPython is available",
    "4" = "{if (verify) 'Run' else 'Skip'} fresh-process verification"
  ))

  if (rlang::is_interactive()) {
    proceed <- utils::askYesNo("Proceed with this setup plan?", default = TRUE)
    if (!isTRUE(proceed)) {
      cli::cli_abort("Setup cancelled.", call = rlang::caller_env())
    }
  }

  actions <- character()
  if (install_runtime) {
    gdal_install_runtime(
      tag = tag,
      gdal_home = default_gdal_home(),
      force = isTRUE(update) || isTRUE(force),
      local_zip = local_zip,
      fallback_zip = fallback_zip
    )
    actions <- c(actions, "runtime")
  }

  after_runtime <- gdal_sitrep(lib = lib, network = FALSE, quiet = TRUE)
  if (!before$runtime_installed && after_runtime$runtime_installed) {
    build_package <- TRUE
  }
  if (!identical(before$bundle_tag, after_runtime$bundle_tag)) {
    build_package <- TRUE
  }

  if (build_package) {
    gdal_build_gdalraster(
      gdal_home = default_gdal_home(),
      lib = lib,
      source_tarball = source_tarball,
      upgrade = upgrade,
      force = after_runtime$gdalraster_installed || isTRUE(force) || isTRUE(update),
      enable_python = TRUE
    )
    actions <- c(actions, "gdalraster")
  } else if (after_runtime$gdalraster_installed) {
    gdal_enable_python(lib = lib, quiet = TRUE)
  }

  verified <- if (isTRUE(verify)) {
    gdal_verify(lib = lib, quiet = TRUE)
  } else {
    NA
  }
  if (isTRUE(verify) && !isTRUE(verified)) {
    cli::cli_abort(
      c(
        "Setup completed, but fresh-process verification failed.",
        "i" = "Run {.fn gdal_sitrep} and {.fn gdal_verify} for details."
      ),
      call = rlang::caller_env()
    )
  }

  cli::cli_h2("Setup complete")
  cli::cli_inform(c(
    "v" = "runtime: {manifest_value(installed_bundle_manifest(), 'Bundle-Tag')}",
    "v" = "gdalraster library: {.path {lib}}",
    "v" = "verification: {.val {verified}}"
  ))
  invisible(list(actions = unique(actions), lib = lib, verified = verified))
}

#' Update the GDAL runtime and rebuild gdalraster
#'
#' @inheritParams gdal_setup
#'
#' @return The result of [gdal_setup()], invisibly.
#' @export
gdal_update <- function(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  tag = "latest",
  local_zip = NULL,
  fallback_zip = NULL,
  source_tarball = NULL,
  upgrade = FALSE,
  verify = TRUE
) {
  gdal_setup(
    lib = lib,
    isolated = isolated,
    user_lib = user_lib,
    update = TRUE,
    force = TRUE,
    tag = tag,
    local_zip = local_zip,
    fallback_zip = fallback_zip,
    source_tarball = source_tarball,
    upgrade = upgrade,
    verify = verify
  )
}

#' Uninstall managed GDAL resources
#'
#' @param lib Library containing the managed `gdalraster` package. Defaults to
#'   `.libPaths()[1]`.
#' @param isolated Remove the package-managed isolated library instead of
#'   `.libPaths()[1]`. Ignored when `lib` is set.
#' @param user_lib Deprecated. `user_lib = TRUE` is now the default;
#'   `user_lib = FALSE` is equivalent to `isolated = TRUE`.
#' @param runtime Remove the GDAL build runtime.
#' @param package Remove the managed `gdalraster` package.
#' @param python Remove managed embedded-Python `.pth` files.
#' @param force Confirm removal in non-interactive sessions.
#'
#' @return Invisibly, the removed paths.
#' @export
gdal_uninstall <- function(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  runtime = TRUE,
  package = TRUE,
  python = TRUE,
  force = FALSE
) {
  abort_if_not_windows()
  check_flag(isolated)
  check_optional_flag(user_lib)
  check_flag(runtime)
  check_flag(package)
  check_flag(python)
  check_flag(force)
  check_optional_string(lib)

  lib <- resolve_gdalraster_lib(lib, isolated = isolated, user_lib = user_lib)
  package_dir <- file.path(lib, "gdalraster")
  targets_exist <- (runtime && dir.exists(default_gdal_home())) ||
    (package && dir.exists(package_dir)) ||
    (python && length(managed_python_pth_files()) > 0L)

  if (!targets_exist) {
    cli::cli_alert_info("No managed GDAL resources were found.")
    return(invisible(character()))
  }
  if (!isTRUE(force)) {
    if (!rlang::is_interactive()) {
      cli::cli_abort(
        "Set {.code force = TRUE} to uninstall managed resources non-interactively.",
        call = rlang::caller_env()
      )
    }
    proceed <- utils::askYesNo("Remove the selected managed GDAL resources?", default = FALSE)
    if (!isTRUE(proceed)) {
      cli::cli_abort("Uninstall cancelled.", call = rlang::caller_env())
    }
  }

  removed <- character()
  if (isTRUE(python)) {
    removed <- c(removed, remove_managed_python_pth())
  }
  if (isTRUE(package) && dir.exists(package_dir)) {
    unlink(package_dir, recursive = TRUE, force = TRUE)
    if (dir.exists(package_dir)) {
      cli::cli_abort(
        "Could not remove {.path {package_dir}}; close sessions using {.pkg gdalraster}.",
        call = rlang::caller_env()
      )
    }
    removed <- c(removed, package_dir)
  }
  if (isTRUE(runtime) && dir.exists(default_gdal_home())) {
    remove_gdal_home(default_gdal_home())
    removed <- c(removed, default_gdal_home())
  }

  cli::cli_alert_success("Removed managed GDAL resources.")
  invisible(unique(removed))
}
