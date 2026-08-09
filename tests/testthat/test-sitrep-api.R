testthat::test_that("sitrep classifies a current vendored installation", {
  home <- create_bundle_fixture(file.path(withr::local_tempdir(), "gdal"))
  lib <- withr::local_tempdir()
  package_dir <- file.path(lib, "gdalraster")
  dir.create(package_dir)
  gdalraster.windows:::write_manifest(
    list(`Bundle-Tag` = "gdal-v9.9.1"),
    gdalraster.windows:::build_manifest_path(package_dir)
  )
  withr::local_options(gdalraster.windows.gdal_home = home)

  testthat::local_mocked_bindings(
    managed_python_pth_files = function() character(),
    path_gdal_dlls = function() character(),
    loaded_gdal_dlls = function() character(),
    .env = asNamespace("gdalraster.windows")
  )

  state <- gdalraster.windows::gdal_sitrep(
    lib = lib,
    network = FALSE,
    quiet = TRUE
  )
  testthat::expect_true(state$runtime_installed)
  testthat::expect_true(state$gdalraster_installed)
  testthat::expect_true(state$build_current)
  testthat::expect_identical(state$bundle_tag, "gdal-v9.9.1")
})

testthat::test_that("sitrep classifies a stale build", {
  home <- create_bundle_fixture(
    file.path(withr::local_tempdir(), "gdal"),
    tag = "gdal-v9.9.2"
  )
  lib <- withr::local_tempdir()
  package_dir <- file.path(lib, "gdalraster")
  dir.create(package_dir)
  gdalraster.windows:::write_manifest(
    list(`Bundle-Tag` = "gdal-v9.9.1"),
    gdalraster.windows:::build_manifest_path(package_dir)
  )
  withr::local_options(gdalraster.windows.gdal_home = home)

  testthat::local_mocked_bindings(
    managed_python_pth_files = function() character(),
    path_gdal_dlls = function() character(),
    loaded_gdal_dlls = function() character(),
    .env = asNamespace("gdalraster.windows")
  )

  state <- gdalraster.windows::gdal_sitrep(
    lib = lib,
    network = FALSE,
    quiet = TRUE
  )
  testthat::expect_false(state$build_current)
  testthat::expect_identical(state$bundle_tag, "gdal-v9.9.2")
  testthat::expect_identical(state$build_tag, "gdal-v9.9.1")
})

testthat::test_that("legacy profile detection recognizes old hook forms", {
  profile <- withr::local_tempfile(fileext = ".Rprofile")
  writeLines("# >>> gdalraster.windows hook >>>", profile)
  testthat::expect_true(
    gdalraster.windows:::legacy_hook_detected(profile)
  )

  writeLines("options(width = 100)", profile)
  testthat::expect_false(
    gdalraster.windows:::legacy_hook_detected(profile)
  )
})

testthat::test_that("removed activation API is no longer exported", {
  removed <- c(
    "activate_gdal_runtime",
    "add_gdal_rprofile_hook",
    "configure_gdal_home",
    "gdal_rprofile_snippet",
    "install_gdal_runtime",
    "install_gdalraster",
    "load_gdal_dll",
    "load_gdalraster",
    "verify_gdalraster_runtime"
  )
  testthat::expect_length(
    intersect(removed, getNamespaceExports("gdalraster.windows")),
    0L
  )
})

testthat::test_that("verification returns false when package is absent", {
  testthat::skip_if_not(.Platform$OS.type == "windows")
  testthat::expect_false(
    gdalraster.windows::gdal_verify(
      lib = withr::local_tempdir(),
      quiet = TRUE
    )
  )
})
