testthat::test_that("gdal_rprofile_snippet includes loader and library path", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- "C:/gdal-ucrt64"
  lib <- "C:/custom-lib"
  txt <- gdalraster.windows::gdal_rprofile_snippet(
    gdal_home = gdal_home,
    lib = lib
  )

  testthat::expect_match(txt, "load_gdal_dll", fixed = TRUE)
  testthat::expect_match(txt, gdal_home, fixed = TRUE)
  testthat::expect_match(txt, lib, fixed = TRUE)
})

testthat::test_that("add_gdal_rprofile_hook appends and updates managed block", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  profile <- withr::local_tempfile(fileext = ".Rprofile")
  writeLines("options(width = 120)", con = profile, useBytes = TRUE)

  gdalraster.windows::add_gdal_rprofile_hook(
    rprofile = profile,
    gdal_home = "C:/gdal-a",
    lib = "C:/lib-a"
  )
  first <- readLines(profile, warn = FALSE)
  testthat::expect_true(any(grepl("gdalraster.windows hook", first, fixed = TRUE)))
  testthat::expect_true(any(grepl("C:/gdal-a", first, fixed = TRUE)))

  gdalraster.windows::add_gdal_rprofile_hook(
    rprofile = profile,
    gdal_home = "C:/gdal-b",
    lib = "C:/lib-b"
  )
  second <- readLines(profile, warn = FALSE)

  testthat::expect_equal(sum(grepl("^# >>> gdalraster.windows hook >>>$", second)), 1L)
  testthat::expect_equal(sum(grepl("^# <<< gdalraster.windows hook <<<$", second)), 1L)
  testthat::expect_true(any(grepl("C:/gdal-b", second, fixed = TRUE)))
  testthat::expect_false(any(grepl("C:/gdal-a", second, fixed = TRUE)))
})
