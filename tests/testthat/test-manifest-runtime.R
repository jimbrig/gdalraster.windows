testthat::test_that("manifest round trip preserves provenance fields", {
  path <- withr::local_tempfile(fileext = ".dcf")
  fields <- list(
    `Bundle-Tag` = "gdal-v9.9.1",
    `GDAL-Version` = "9.9.1",
    `Asset-Name` = "fixture.zip"
  )

  gdalraster.windows:::write_manifest(fields, path)
  result <- gdalraster.windows:::read_manifest(path)

  testthat::expect_identical(result[["Bundle-Tag"]], "gdal-v9.9.1")
  testthat::expect_identical(result[["GDAL-Version"]], "9.9.1")
  testthat::expect_null(gdalraster.windows:::read_manifest(withr::local_tempfile()))
})

testthat::test_that("build provenance classifies current and stale builds", {
  bundle <- list(`Bundle-Tag` = "gdal-v9.9.1")
  current <- list(`Bundle-Tag` = "gdal-v9.9.1")
  stale <- list(`Bundle-Tag` = "gdal-v9.9.0")

  testthat::expect_true(gdalraster.windows:::build_is_current(bundle, current))
  testthat::expect_false(gdalraster.windows:::build_is_current(bundle, stale))
  testthat::expect_false(gdalraster.windows:::build_is_current(bundle, NULL))
})

testthat::test_that("local bundle install writes and preserves its manifest", {
  testthat::skip_if_not(.Platform$OS.type == "windows")
  zip <- withr::local_tempfile(fileext = ".zip")
  create_bundle_zip(zip)
  home <- file.path(withr::local_tempdir(), "gdal")

  gdalraster.windows::gdal_install_runtime(
    gdal_home = home,
    local_zip = zip,
    force = TRUE
  )

  manifest <- gdalraster.windows:::installed_bundle_manifest(home)
  testthat::expect_identical(manifest[["Bundle-Tag"]], "gdal-v9.9.1")
  testthat::expect_true(file.exists(file.path(home, "bin", "libgdal-39.dll")))
  testthat::expect_true(dir.exists(file.path(home, "python", "osgeo_utils")))
})

testthat::test_that("runtime install skips a matching release without download", {
  testthat::skip_if_not(.Platform$OS.type == "windows")
  home <- create_bundle_fixture(file.path(withr::local_tempdir(), "gdal"))

  testthat::local_mocked_bindings(
    resolve_release_asset = function(...) {
      list(
        name = "fixture.zip",
        tag = "gdal-v9.9.1",
        url = "https://example.invalid/fixture.zip"
      )
    },
    download_release_asset = function(...) {
      testthat::fail("matching installs must not download")
    },
    .env = asNamespace("gdalraster.windows")
  )

  testthat::expect_message(
    gdalraster.windows::gdal_install_runtime(gdal_home = home),
    "already installed"
  )
})

testthat::test_that("runtime install reports an available update without replacing", {
  testthat::skip_if_not(.Platform$OS.type == "windows")
  home <- create_bundle_fixture(
    file.path(withr::local_tempdir(), "gdal"),
    tag = "gdal-v9.9.0"
  )

  testthat::local_mocked_bindings(
    resolve_release_asset = function(...) {
      list(
        name = "fixture.zip",
        tag = "gdal-v9.9.1",
        url = "https://example.invalid/fixture.zip"
      )
    },
    .env = asNamespace("gdalraster.windows")
  )

  testthat::expect_message(
    gdalraster.windows::gdal_install_runtime(gdal_home = home),
    "gdal_update"
  )
  testthat::expect_identical(
    gdalraster.windows:::manifest_value(
      gdalraster.windows:::installed_bundle_manifest(home),
      "Bundle-Tag"
    ),
    "gdal-v9.9.0"
  )
})

testthat::test_that("runtime install uses a local fallback after release failure", {
  testthat::skip_if_not(.Platform$OS.type == "windows")
  zip <- withr::local_tempfile(fileext = ".zip")
  create_bundle_zip(zip)
  home <- file.path(withr::local_tempdir(), "gdal")

  testthat::local_mocked_bindings(
    resolve_release_asset = function(...) cli::cli_abort("forced failure"),
    .env = asNamespace("gdalraster.windows")
  )

  gdalraster.windows::gdal_install_runtime(
    gdal_home = home,
    fallback_zip = zip,
    force = TRUE
  )
  testthat::expect_true(file.exists(file.path(home, "bin", "libgdal-39.dll")))
})

testthat::test_that("release selection ignores package and draft releases", {
  releases <- list(
    release_fixture("v9.0.0"),
    release_fixture(
      "gdal-v9.9.2",
      draft = TRUE,
      assets = list(asset_fixture(1L, "gdal-ucrt64-v9.9.2.zip", "draft"))
    ),
    release_fixture(
      "gdal-v9.9.1",
      assets = list(asset_fixture(2L, "gdal-ucrt64-v9.9.1.zip", "winner"))
    )
  )

  result <- gdalraster.windows:::select_release_asset(
    releases,
    gdalraster.windows:::.bundle_asset_pattern
  )
  testthat::expect_identical(result$tag, "gdal-v9.9.1")
  testthat::expect_identical(result$url, "winner")
})

testthat::test_that("release selection ignores package tags that still carry a bundle zip", {
  releases <- list(
    release_fixture(
      "v0.3.1",
      assets = list(
        asset_fixture(1L, "gdal-ucrt64-v3.13.1-windows-x64.zip", "stale-package")
      ),
      published_at = "2026-07-04T01:43:56Z"
    ),
    release_fixture(
      "gdal-v3.13.2",
      assets = list(
        asset_fixture(2L, "gdal-ucrt64-v3.13.2-windows-x64.zip", "bundle")
      ),
      published_at = "2026-08-09T05:13:21Z"
    )
  )

  result <- gdalraster.windows:::select_release_asset(
    releases,
    gdalraster.windows:::.bundle_asset_pattern
  )
  testthat::expect_identical(result$tag, "gdal-v3.13.2")
  testthat::expect_identical(result$url, "bundle")
})

testthat::test_that("release selection prefers the newest published gdal-v tag", {
  releases <- list(
    release_fixture(
      "gdal-v9.9.0",
      assets = list(asset_fixture(1L, "gdal-ucrt64-v9.9.0.zip", "older")),
      published_at = "2026-01-01T00:00:00Z"
    ),
    release_fixture(
      "gdal-v9.9.1",
      assets = list(asset_fixture(2L, "gdal-ucrt64-v9.9.1.zip", "newer")),
      published_at = "2026-06-01T00:00:00Z"
    )
  )

  result <- gdalraster.windows:::select_release_asset(
    releases,
    gdalraster.windows:::.bundle_asset_pattern
  )
  testthat::expect_identical(result$tag, "gdal-v9.9.1")
  testthat::expect_identical(result$url, "newer")
})

testthat::test_that("stale runtime helpers preserve unrelated directories", {
  root <- withr::local_tempdir()
  home <- file.path(root, "gdal")
  stale <- file.path(root, "gdal.stale-test")
  unrelated <- file.path(root, "library")
  dir.create(file.path(home, "bin"), recursive = TRUE)
  dir.create(stale)
  dir.create(unrelated)
  writeLines("dll", file.path(home, "bin", "libgdal-39.dll"))

  moved <- gdalraster.windows:::move_tree_aside(
    home,
    file.path(root, "gdal.stale-moved")
  )
  testthat::expect_true(moved)
  testthat::expect_false(dir.exists(home))

  gdalraster.windows:::cleanup_stale_runtimes(home)
  testthat::expect_false(dir.exists(stale))
  testthat::expect_true(dir.exists(unrelated))
})
