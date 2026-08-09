#' Verify the self-contained gdalraster installation
#'
#' Runs verification in fresh `Rscript --vanilla` processes. Checks the GDAL
#' Algorithm API, GEOS and CRS support, Arrow/Parquet/HDF5/netCDF driver
#' registration, a first Parquet dataset open, and the GeoPackage Python
#' validator when embedded Python has been provisioned.
#'
#' @param lib Library containing the managed `gdalraster` package.
#' @param user_lib Use `.libPaths()[1]`.
#' @param python Run the embedded-Python validation when its managed `.pth`
#'   file is ready.
#' @param quiet Suppress verification output.
#'
#' @return `TRUE` on success and `FALSE` on failure.
#' @export
gdal_verify <- function(
  lib = NULL,
  user_lib = FALSE,
  python = TRUE,
  quiet = FALSE
) {
  abort_if_not_windows()
  check_flag(user_lib)
  check_flag(python)
  check_flag(quiet)
  check_optional_string(lib)

  lib <- resolve_gdalraster_lib(lib, user_lib)
  package_dir <- file.path(lib, "gdalraster")
  if (!dir.exists(package_dir)) {
    if (!isTRUE(quiet)) {
      cli::cli_alert_danger("{.pkg gdalraster} is not installed at {.path {package_dir}}.")
    }
    return(FALSE)
  }

  work <- tempfile("gdal-verify-")
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  withr::defer(unlink(work, recursive = TRUE, force = TRUE))
  parquet <- file.path(work, "first-open.parquet")
  run_python <- isTRUE(python) && python_is_ready(package_dir)

  # Create a minimal Parquet dataset by translating GeoJSON. Direct
  # ogr_ds_create(..., format = "Parquet") currently aborts inside GDAL/Arrow
  # on this stack; vectortranslate exercises the Parquet driver write path
  # without that create API.
  generator <- c(
    sprintf("library(gdalraster, lib.loc = %s)", deparse(lib)),
    sprintf("path <- %s", deparse(parquet)),
    "gj <- tempfile(fileext = '.geojson')",
    paste0(
      "writeLines(",
      "'{\"type\":\"FeatureCollection\",\"features\":[{",
      "\"type\":\"Feature\",\"properties\":{\"id\":1},",
      "\"geometry\":{\"type\":\"Point\",\"coordinates\":[0,0]}}]}', gj)"
    ),
    paste0(
      "ok <- gdalraster::gdal_utils(",
      "'vectortranslate', source = gj, destination = path, ",
      "cl_arg = c('-f', 'Parquet', '-nlt', 'POINT'))"
    ),
    "stopifnot(isTRUE(ok), file.exists(path))"
  )
  generated <- run_fresh_rscript(generator)
  if (generated$status != 0L) {
    if (!isTRUE(quiet)) {
      cli::cli_alert_danger("Parquet fixture creation failed in a fresh process.")
      cli::cli_inform(c("x" = "{paste(generated$output, collapse = '\n')}"))
    }
    return(FALSE)
  }

  verify <- c(
    sprintf("library(gdalraster, lib.loc = %s)", deparse(lib)),
    "algorithms <- gdalraster::gdal_global_reg_names()",
    "stopifnot(length(algorithms) > 0L)",
    "formats <- gdalraster::gdal_formats()$short_name",
    sprintf("required <- %s", deparse(.required_gdal_drivers)),
    paste0(
      "stopifnot(all(vapply(required, function(driver) ",
      "any(grepl(driver, formats, ignore.case = TRUE)), logical(1))))"
    ),
    "stopifnot(isTRUE(gdalraster::has_geos()))",
    "stopifnot(nzchar(gdalraster::srs_to_wkt('EPSG:4326')))",
    sprintf("parquet <- %s", deparse(parquet)),
    "info <- gdalraster::ogrinfo(parquet, cout = FALSE)",
    "stopifnot(length(info) > 0L)",
    if (run_python) {
      c(
        sprintf("gpkg <- %s", deparse(file.path(work, "verify.gpkg"))),
        paste0(
          "gdalraster::ogr_ds_create(",
          "format = 'GPKG', dsn = gpkg, layer = 'points', ",
          "geom_type = 'Point', fld_name = 'id', fld_type = 'OFTInteger', ",
          "return_obj = FALSE)"
        ),
        "validator <- gdalraster::gdal_alg(cmd = 'driver gpkg validate')",
        "validator$setArg('dataset', gpkg)",
        "validator$setArg('full-check', TRUE)",
        "stopifnot(isTRUE(validator$run()))",
        "validator$output()"
      )
    } else {
      "cat('embedded_python=skipped\\n')"
    },
    paste0(
      "cat('algorithms=', length(algorithms), ",
      "' drivers=', paste(required, collapse = ','), '\\n', sep = '')"
    )
  )
  checked <- run_fresh_rscript(verify)
  ok <- identical(checked$status, 0L)

  if (!isTRUE(quiet)) {
    if (ok) {
      cli::cli_alert_success("Fresh-process GDAL verification passed.")
      if (!run_python && isTRUE(python)) {
        cli::cli_alert_warning(
          "Embedded-Python validation was skipped because no ready managed {.file .pth} file was found."
        )
      }
    } else {
      cli::cli_alert_danger("Fresh-process GDAL verification failed.")
      cli::cli_inform(c("x" = "{paste(checked$output, collapse = '\n')}"))
    }
  }
  ok
}

#' @keywords internal
#' @noRd
python_is_ready <- function(package_dir) {
  target <- normalizePath(
    file.path(package_dir, "python"),
    winslash = "/",
    mustWork = FALSE
  )
  paths <- managed_python_pth_files()
  targets <- vapply(paths, pth_target, character(1))
  any(!is.na(targets) & identical_paths(targets, target))
}

#' @keywords internal
#' @noRd
run_fresh_rscript <- function(code) {
  script <- tempfile("gdal-verify-", fileext = ".R")
  stdout <- tempfile("gdal-verify-", fileext = ".out")
  stderr <- tempfile("gdal-verify-", fileext = ".err")
  writeLines(code, script, useBytes = TRUE)
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  if (!file.exists(rscript)) {
    rscript <- Sys.which("Rscript")
  }

  status <- withr::with_envvar(
    c(
      GDAL_DATA = NA,
      PROJ_DATA = NA,
      PROJ_LIB = NA,
      PYTHONPATH = NA,
      GDALRASTER_WINDOWS_GDAL_HOME = NA
    ),
    system2(
      rscript,
      args = c("--vanilla", shQuote(script)),
      stdout = stdout,
      stderr = stderr,
      wait = TRUE
    )
  )
  output <- c(
    if (file.exists(stdout)) readLines(stdout, warn = FALSE) else character(),
    if (file.exists(stderr)) readLines(stderr, warn = FALSE) else character()
  )
  list(status = as.integer(status), output = output)
}
