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
    loaded_gdal_dlls = function() character(),
    visible_gdalraster_dir = function() "",
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
    loaded_gdal_dlls = function() character(),
    visible_gdalraster_dir = function() "",
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

testthat::test_that("gdal_home is slash-normalized", {
  home <- gdalraster.windows::gdal_home()
  testthat::expect_false(grepl("\\\\", home))
  testthat::expect_identical(
    home,
    normalizePath(home, winslash = "/", mustWork = FALSE)
  )
})

testthat::test_that("library resolution defaults to .libPaths()[1]", {
  testthat::expect_identical(
    gdalraster.windows:::resolve_gdalraster_lib(),
    normalizePath(.libPaths()[[1L]], winslash = "/", mustWork = FALSE)
  )
})

testthat::test_that("isolated library is opt-in", {
  testthat::expect_identical(
    gdalraster.windows:::resolve_gdalraster_lib(isolated = TRUE),
    gdalraster.windows:::default_gdalraster_lib()
  )
})

testthat::test_that("explicit lib wins over isolated", {
  lib <- normalizePath(withr::local_tempdir(), winslash = "/", mustWork = FALSE)
  testthat::expect_identical(
    gdalraster.windows:::resolve_gdalraster_lib(lib = lib, isolated = TRUE),
    lib
  )
})

testthat::test_that("user_lib = FALSE still selects the isolated library", {
  testthat::expect_identical(
    gdalraster.windows:::resolve_gdalraster_lib(user_lib = FALSE),
    gdalraster.windows:::default_gdalraster_lib()
  )
})

testthat::test_that("sitrep reports missing provenance instead of treating NA as a tag", {
  home <- create_bundle_fixture(file.path(withr::local_tempdir(), "gdal"))
  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "gdalraster"))
  withr::local_options(gdalraster.windows.gdal_home = home)

  testthat::local_mocked_bindings(
    managed_python_pth_files = function() character(),
    loaded_gdal_dlls = function() character(),
    visible_gdalraster_dir = function() "",
    .env = asNamespace("gdalraster.windows")
  )

  state <- gdalraster.windows::gdal_sitrep(
    lib = lib,
    network = FALSE,
    quiet = TRUE
  )
  testthat::expect_true(state$gdalraster_installed)
  testthat::expect_true(is.na(state$build_tag))
  testthat::expect_true(is.na(state$gdalraster_version))
  testthat::expect_false(state$build_current)
  testthat::expect_identical(
    gdalraster.windows:::gdalraster_status_label(state),
    "installed (missing provenance)"
  )
})

testthat::test_that("sitrep reports the gdalraster package version, not the GDAL tag", {
  home <- create_bundle_fixture(file.path(withr::local_tempdir(), "gdal"))
  lib <- withr::local_tempdir()
  package_dir <- file.path(lib, "gdalraster")
  dir.create(package_dir)
  writeLines(
    c("Package: gdalraster", "Version: 2.6.1.9001"),
    file.path(package_dir, "DESCRIPTION")
  )
  gdalraster.windows:::write_manifest(
    list(`Bundle-Tag` = "gdal-v9.9.1"),
    gdalraster.windows:::build_manifest_path(package_dir)
  )
  withr::local_options(gdalraster.windows.gdal_home = home)

  testthat::local_mocked_bindings(
    managed_python_pth_files = function() character(),
    loaded_gdal_dlls = function() character(),
    visible_gdalraster_dir = function() "",
    .env = asNamespace("gdalraster.windows")
  )

  state <- gdalraster.windows::gdal_sitrep(
    lib = lib,
    network = FALSE,
    quiet = TRUE
  )
  testthat::expect_identical(state$bundle_tag, "gdal-v9.9.1")
  testthat::expect_identical(state$gdalraster_version, "2.6.1.9001")
  testthat::expect_identical(
    gdalraster.windows:::gdalraster_status_label(state),
    "2.6.1.9001"
  )
})

testthat::test_that("sitrep points at a managed build visible on .libPaths()", {
  home <- create_bundle_fixture(file.path(withr::local_tempdir(), "gdal"))
  inspected_lib <- withr::local_tempdir()
  dir.create(file.path(inspected_lib, "gdalraster"))
  visible_dir <- file.path(withr::local_tempdir(), "gdalraster")
  dir.create(visible_dir)
  gdalraster.windows:::write_manifest(
    list(`Bundle-Tag` = "gdal-v9.9.1"),
    gdalraster.windows:::build_manifest_path(visible_dir)
  )
  withr::local_options(gdalraster.windows.gdal_home = home)

  testthat::local_mocked_bindings(
    managed_python_pth_files = function() character(),
    loaded_gdal_dlls = function() character(),
    visible_gdalraster_dir = function() {
      normalizePath(visible_dir, winslash = "/", mustWork = TRUE)
    },
    .env = asNamespace("gdalraster.windows")
  )

  state <- gdalraster.windows::gdal_sitrep(
    lib = inspected_lib,
    network = FALSE,
    quiet = TRUE
  )
  testthat::expect_true(state$foreign_gdalraster)
  testthat::expect_true(state$visible_build_current)
  testthat::expect_false(state$build_current)
})

testthat::test_that("path gdal scan ignores managed runtime and package DLLs", {
  root <- withr::local_tempdir()
  home <- file.path(root, "gdal")
  package_dir <- file.path(root, "gdalraster")
  other <- file.path(root, "other-gdal")
  dir.create(file.path(home, "bin"), recursive = TRUE)
  dir.create(file.path(package_dir, "libs", "x64"), recursive = TRUE)
  dir.create(other)
  writeLines("dll", file.path(home, "bin", "libgdal-39.dll"))
  writeLines("dll", file.path(package_dir, "libs", "x64", "libgdal-39.dll"))
  writeLines("dll", file.path(other, "libgdal-39.dll"))

  withr::local_path(
    c(
      normalizePath(file.path(home, "bin"), winslash = "/", mustWork = TRUE),
      normalizePath(file.path(package_dir, "libs", "x64"), winslash = "/", mustWork = TRUE),
      normalizePath(other, winslash = "/", mustWork = TRUE)
    ),
    action = "replace"
  )

  dlls <- gdalraster.windows:::path_gdal_dlls(exclude = c(home, package_dir))
  testthat::expect_length(dlls, 1L)
  testthat::expect_true(gdalraster.windows:::path_is_under(dlls, other))
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
