create_runtime_zip_fixture <- function(path) {
  root <- withr::local_tempdir()
  bundle <- file.path(root, "bundle")

  dir.create(file.path(bundle, "bin"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(bundle, "share", "gdal"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(bundle, "share", "proj"), recursive = TRUE, showWarnings = FALSE)

  file.create(file.path(bundle, "bin", "libgdal-39.dll"))
  file.create(file.path(bundle, "share", "gdal", "gdal_datum.csv"))
  file.create(file.path(bundle, "share", "proj", "proj.db"))

  old_wd <- setwd(root)
  withr::defer(setwd(old_wd))
  utils::zip(zipfile = path, files = "bundle")
  path
}

testthat::test_that("dll discovery supports dynamic GDAL soname", {
  bin_dir <- withr::local_tempdir()
  file.create(file.path(bin_dir, "libgdal-39.dll"))
  file.create(file.path(bin_dir, "libgdal-40.dll"))

  gdal_home <- withr::local_tempdir()
  dir.create(file.path(gdal_home, "bin"), recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(bin_dir, "libgdal-39.dll"), file.path(gdal_home, "bin", "libgdal-39.dll"))
  file.copy(file.path(bin_dir, "libgdal-40.dll"), file.path(gdal_home, "bin", "libgdal-40.dll"))

  dlls <- gdalraster.windows:::gdal_dll_candidates(gdal_home)
  testthat::expect_true(length(dlls) >= 2L)
  testthat::expect_true(grepl("^libgdal-[0-9]+\\.dll$", basename(gdalraster.windows:::gdal_dll_path(gdal_home))))
})

testthat::test_that("detect_gdal_root finds extracted runtime root", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "gdal-bundle", "bin"), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(root, "gdal-bundle", "bin", "libgdal-39.dll"))

  detected <- gdalraster.windows:::detect_gdal_root(root)
  testthat::expect_equal(
    normalizePath(detected, winslash = "/", mustWork = TRUE),
    normalizePath(file.path(root, "gdal-bundle"), winslash = "/", mustWork = TRUE)
  )
})

testthat::test_that("install_gdal_runtime installs from local zip", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  zip_path <- withr::local_tempfile(fileext = ".zip")
  create_runtime_zip_fixture(zip_path)

  gdal_home <- withr::local_tempdir()
  gdalraster.windows::install_gdal_runtime(
    gdal_home = gdal_home,
    overwrite = TRUE,
    local_zip = zip_path
  )

  testthat::expect_true(
    file.exists(file.path(gdal_home, "bin", "libgdal-39.dll"))
  )
  testthat::expect_true(
    dir.exists(file.path(gdal_home, "share", "gdal"))
  )
  testthat::expect_true(
    dir.exists(file.path(gdal_home, "share", "proj"))
  )
})

testthat::test_that("install_gdal_runtime uses fallback zip when release lookup fails", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  zip_path <- withr::local_tempfile(fileext = ".zip")
  create_runtime_zip_fixture(zip_path)

  testthat::local_mocked_bindings(
    resolve_release_asset = function(...) {
      cli::cli_abort("forced release lookup failure for test")
    },
    .env = asNamespace("gdalraster.windows")
  )

  gdal_home <- withr::local_tempdir()
  gdalraster.windows::install_gdal_runtime(
    repo = "jimbrig/gdalraster.windows",
    tag = "latest",
    gdal_home = gdal_home,
    overwrite = TRUE,
    fallback_zip = zip_path
  )

  testthat::expect_true(
    file.exists(file.path(gdal_home, "bin", "libgdal-39.dll"))
  )
})

testthat::test_that("load_gdalraster fails clearly when isolated lib missing package", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  lib <- withr::local_tempdir()
  gdal_home <- withr::local_tempdir()
  dir.create(file.path(gdal_home, "bin"), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(gdal_home, "bin", "libgdal-39.dll"))

  testthat::expect_snapshot(error = TRUE, {
    gdalraster.windows::load_gdalraster(lib = lib, gdal_home = gdal_home, quiet = TRUE)
  })
})
