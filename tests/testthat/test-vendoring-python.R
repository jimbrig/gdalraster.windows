testthat::test_that("vendoring copies DLLs, data, and Python without deleting package DLL", {
  home <- create_bundle_fixture(file.path(withr::local_tempdir(), "gdal"))
  package_dir <- file.path(withr::local_tempdir(), "gdalraster")
  dir.create(file.path(package_dir, "libs", "x64"), recursive = TRUE)
  writeLines("package", file.path(package_dir, "libs", "x64", "gdalraster.dll"))
  dir.create(file.path(package_dir, "gdal"))
  writeLines("stale", file.path(package_dir, "gdal", "stale.csv"))

  gdalraster.windows:::vendor_gdalraster(package_dir, home)

  testthat::expect_true(
    file.exists(file.path(package_dir, "libs", "x64", "gdalraster.dll"))
  )
  testthat::expect_true(
    file.exists(file.path(package_dir, "libs", "x64", "libgdal-39.dll"))
  )
  testthat::expect_false(file.exists(file.path(package_dir, "gdal", "stale.csv")))
  testthat::expect_true(file.exists(file.path(package_dir, "proj", "proj.db")))
  testthat::expect_true(
    file.exists(file.path(package_dir, "python", "osgeo_utils", "__init__.py"))
  )
})

testthat::test_that("package replacement is staged and removes its backup", {
  root <- withr::local_tempdir()
  staged <- file.path(root, "stage", "gdalraster")
  target <- file.path(root, "library", "gdalraster")
  dir.create(staged, recursive = TRUE)
  dir.create(target, recursive = TRUE)
  writeLines("new", file.path(staged, "marker"))
  writeLines("old", file.path(target, "marker"))

  gdalraster.windows:::replace_package_tree(staged, target)

  testthat::expect_identical(readLines(file.path(target, "marker")), "new")
  testthat::expect_false(dir.exists(staged))
  testthat::expect_length(
    list.files(dirname(target), pattern = "\\.previous-"),
    0L
  )
})

testthat::test_that("managed Python path provisioning is idempotent", {
  testthat::skip_if_not(.Platform$OS.type == "windows")
  lib <- withr::local_tempdir()
  package_python <- file.path(lib, "gdalraster", "python", "osgeo_utils")
  dir.create(package_python, recursive = TRUE)
  site <- withr::local_tempdir()

  first <- gdalraster.windows::gdal_enable_python(
    lib = lib,
    site_packages = site,
    quiet = TRUE
  )
  second <- gdalraster.windows::gdal_enable_python(
    lib = lib,
    site_packages = site,
    quiet = TRUE
  )

  testthat::expect_identical(first, second)
  lines <- readLines(first)
  testthat::expect_identical(
    lines[[1L]],
    gdalraster.windows:::.python_pth_marker
  )
  testthat::expect_true(dir.exists(lines[[2L]]))
  testthat::expect_length(list.files(site, pattern = "\\.pth$"), 1L)
})

testthat::test_that("pth target parsing rejects unmanaged files", {
  path <- withr::local_tempfile(fileext = ".pth")
  writeLines("C:/something", path)
  testthat::expect_true(is.na(gdalraster.windows:::pth_target(path)))

  writeLines(
    c(gdalraster.windows:::.python_pth_marker, "C:/managed"),
    path
  )
  testthat::expect_identical(
    gdalraster.windows:::pth_target(path),
    "C:/managed"
  )
})

testthat::test_that("runtime contract requires all vendoring inputs", {
  home <- create_bundle_fixture(file.path(withr::local_tempdir(), "gdal"))
  testthat::expect_true(gdalraster.windows:::validate_runtime_contract(home))

  unlink(file.path(home, "python"), recursive = TRUE)
  testthat::expect_error(
    gdalraster.windows:::validate_runtime_contract(home),
    "incomplete"
  )
})
