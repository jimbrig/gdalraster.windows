testthat::test_that("pkg_startup_msg shows setup-needed guidance", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  withr::local_options(gdalraster.windows.gdal_home = withr::local_tempdir())
  txt <- paste(gdalraster.windows:::pkg_startup_msg(), collapse = "\n")

  testthat::expect_match(txt, "setup needed", fixed = TRUE)
  testthat::expect_match(txt, "install_gdal_runtime", fixed = TRUE)
  testthat::expect_match(txt, "install_gdalraster", fixed = TRUE)
})

testthat::test_that("pkg_startup_msg shows ready-style details", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- withr::local_tempdir()
  dir.create(file.path(gdal_home, "bin"), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(gdal_home, "bin", "libgdal-39.dll"))

  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "gdalraster"), recursive = TRUE, showWarnings = FALSE)

  withr::local_options(gdalraster.windows.gdal_home = gdal_home)
  testthat::local_mocked_bindings(
    default_gdalraster_lib = function() lib,
    .env = asNamespace("gdalraster.windows")
  )
  testthat::local_mocked_bindings(
    runtime_sitrep = function() {
      list(
        gdal_home = gdal_home,
        gdal_bin = file.path(gdal_home, "bin"),
        gdal_dll = file.path(gdal_home, "bin", "libgdal-39.dll"),
        custom_lib = lib,
        gdal_home_exists = TRUE,
        gdal_dll_exists = TRUE,
        custom_lib_exists = TRUE,
        custom_gdalraster_exists = TRUE,
        gdalraster_loaded = TRUE
      )
    },
    .env = asNamespace("gdalraster.windows")
  )

  txt <- paste(gdalraster.windows:::pkg_startup_msg(), collapse = "\n")
  testthat::expect_match(txt, "runtime:", fixed = TRUE)
  testthat::expect_match(txt, "gdalraster lib:", fixed = TRUE)
})
