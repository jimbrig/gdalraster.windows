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
