create_runtime_zip_fixture <- function(path) {
  root <- withr::local_tempdir()
  bundle <- file.path(root, "bundle")

  dir.create(file.path(bundle, "bin"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(bundle, "share", "gdal"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(bundle, "share", "proj"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(bundle, "python", "osgeo_utils", "samples"), recursive = TRUE, showWarnings = FALSE)

  file.create(file.path(bundle, "bin", "libgdal-39.dll"))
  file.create(file.path(bundle, "share", "gdal", "gdal_datum.csv"))
  file.create(file.path(bundle, "share", "proj", "proj.db"))
  file.create(file.path(bundle, "python", "osgeo_utils", "__init__.py"))
  file.create(file.path(bundle, "python", "osgeo_utils", "samples", "validate_gpkg.py"))

  old_wd <- setwd(root)
  withr::defer(setwd(old_wd))
  utils::zip(zipfile = path, files = "bundle")
  path
}

create_gdal_home_fixture <- function(python = TRUE) {
  gdal_home <- withr::local_tempdir(.local_envir = parent.frame())
  dir.create(file.path(gdal_home, "bin"), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(gdal_home, "bin", "libgdal-39.dll"))
  if (isTRUE(python)) {
    dir.create(file.path(gdal_home, "python", "osgeo_utils"), recursive = TRUE, showWarnings = FALSE)
    file.create(file.path(gdal_home, "python", "osgeo_utils", "__init__.py"))
  }
  gdal_home
}

# builds a synthetic github release list entry; versions are deliberately
# fake (v9.x) so the fixtures cannot be mistaken for real release tags
release_fixture <- function(tag, assets = list(), draft = FALSE, prerelease = FALSE) {
  list(tag_name = tag, draft = draft, prerelease = prerelease, assets = assets)
}

asset_fixture <- function(id, name, url) {
  list(id = id, name = name, browser_download_url = url)
}

testthat::test_that("select_release_asset skips releases without a matching bundle asset", {
  releases <- list(
    # package release: no bundle asset, must be skipped
    release_fixture("v9.0.0"),
    # draft bundle release: must be skipped even though the asset matches
    release_fixture(
      "gdal-v9.9.2",
      draft = TRUE,
      assets = list(
        asset_fixture(30L, "gdal-ucrt64-v9.9.2-windows-x64.zip", "https://example.com/draft.zip")
      )
    ),
    # newest published bundle release: wins, non-matching assets ignored
    release_fixture(
      "gdal-v9.9.1",
      assets = list(
        asset_fixture(10L, "checksums.txt", "https://example.com/checksums.txt"),
        asset_fixture(11L, "gdal-ucrt64-v9.9.1-windows-x64.zip", "https://example.com/bundle.zip")
      )
    ),
    # older published bundle release: valid but not first
    release_fixture(
      "gdal-v9.9.0",
      assets = list(
        asset_fixture(20L, "gdal-ucrt64-v9.9.0-windows-x64.zip", "https://example.com/old.zip")
      )
    )
  )

  asset <- gdalraster.windows:::select_release_asset(
    releases,
    asset_pattern = gdalraster.windows:::.bundle_asset_pattern
  )

  testthat::expect_equal(asset$tag, "gdal-v9.9.1")
  testthat::expect_equal(asset$name, "gdal-ucrt64-v9.9.1-windows-x64.zip")
  testthat::expect_equal(asset$url, "https://example.com/bundle.zip")
})

testthat::test_that("select_release_asset errors when no release carries a bundle asset", {
  releases <- list(release_fixture("v9.0.0"))

  testthat::expect_error(
    gdalraster.windows:::select_release_asset(
      releases,
      asset_pattern = gdalraster.windows:::.bundle_asset_pattern
    ),
    "No release with an asset matching"
  )
})

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
  testthat::expect_true(
    file.exists(file.path(gdal_home, "python", "osgeo_utils", "__init__.py"))
  )
})

testthat::test_that("activate_gdal_runtime prepends bundled python dir to PYTHONPATH", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- create_gdal_home_fixture(python = TRUE)
  withr::local_envvar(PYTHONPATH = NA)

  res <- gdalraster.windows::activate_gdal_runtime(
    gdal_home = gdal_home,
    preload = FALSE,
    quiet = TRUE
  )

  python_dir <- file.path(normalizePath(gdal_home, winslash = "/"), "python")
  testthat::expect_equal(res$gdal_python, python_dir)
  testthat::expect_equal(Sys.getenv("PYTHONPATH"), python_dir)
})

testthat::test_that("activate_gdal_runtime preserves existing PYTHONPATH entries", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- create_gdal_home_fixture(python = TRUE)
  existing <- "C:/some/other/site-packages"
  withr::local_envvar(PYTHONPATH = existing)

  gdalraster.windows::activate_gdal_runtime(
    gdal_home = gdal_home,
    preload = FALSE,
    quiet = TRUE
  )

  python_dir <- file.path(normalizePath(gdal_home, winslash = "/"), "python")
  parts <- strsplit(Sys.getenv("PYTHONPATH"), .Platform$path.sep, fixed = TRUE)[[1]]
  testthat::expect_equal(parts, c(python_dir, existing))
})

testthat::test_that("activate_gdal_runtime does not duplicate python dir on repeat activation", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- create_gdal_home_fixture(python = TRUE)
  withr::local_envvar(PYTHONPATH = NA)

  gdalraster.windows::activate_gdal_runtime(gdal_home = gdal_home, preload = FALSE, quiet = TRUE)
  gdalraster.windows::activate_gdal_runtime(gdal_home = gdal_home, preload = FALSE, quiet = TRUE)

  python_dir <- file.path(normalizePath(gdal_home, winslash = "/"), "python")
  parts <- strsplit(Sys.getenv("PYTHONPATH"), .Platform$path.sep, fixed = TRUE)[[1]]
  testthat::expect_equal(sum(parts == python_dir), 1L)
})

testthat::test_that("activate_gdal_runtime leaves PYTHONPATH untouched without bundled python dir", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- create_gdal_home_fixture(python = FALSE)
  withr::local_envvar(PYTHONPATH = NA)

  res <- gdalraster.windows::activate_gdal_runtime(
    gdal_home = gdal_home,
    preload = FALSE,
    quiet = TRUE
  )

  testthat::expect_true(is.na(res$gdal_python))
  testthat::expect_equal(Sys.getenv("PYTHONPATH"), "")
})

testthat::test_that("install_gdal_runtime fails fast on existing gdal_home before any download", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  testthat::local_mocked_bindings(
    resolve_release_asset = function(...) {
      cli::cli_abort("download must not be attempted for this test")
    },
    .env = asNamespace("gdalraster.windows")
  )

  gdal_home <- withr::local_tempdir()
  testthat::expect_error(
    gdalraster.windows::install_gdal_runtime(
      gdal_home = gdal_home,
      overwrite = FALSE
    ),
    "already exists"
  )
})

testthat::test_that("install_gdal_runtime with overwrite replaces an existing runtime", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  zip_path <- withr::local_tempfile(fileext = ".zip")
  create_runtime_zip_fixture(zip_path)

  gdal_home <- withr::local_tempdir()
  dir.create(file.path(gdal_home, "bin"), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(gdal_home, "bin", "stale-marker.dll"))

  gdalraster.windows::install_gdal_runtime(
    gdal_home = gdal_home,
    overwrite = TRUE,
    local_zip = zip_path
  )

  testthat::expect_false(
    file.exists(file.path(gdal_home, "bin", "stale-marker.dll"))
  )
  testthat::expect_true(
    file.exists(file.path(gdal_home, "bin", "libgdal-39.dll"))
  )
})

testthat::test_that("activate_gdal_runtime errors loudly when DLL preload fails", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  # fixture dll is an empty file, so dyn.load must fail
  gdal_home <- create_gdal_home_fixture(python = FALSE)

  testthat::expect_error(
    gdalraster.windows::activate_gdal_runtime(
      gdal_home = gdal_home,
      preload = TRUE,
      quiet = TRUE
    ),
    "Failed to preload the GDAL runtime DLL"
  )
})

testthat::test_that("loaded_runtime_dlls is empty for a never-loaded runtime", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- create_gdal_home_fixture(python = FALSE)
  testthat::expect_length(
    gdalraster.windows:::loaded_runtime_dlls(gdal_home),
    0L
  )
})

testthat::test_that("verify_gdalraster_runtime returns FALSE when activation fails", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  gdal_home <- create_gdal_home_fixture(python = FALSE)
  ok <- gdalraster.windows::verify_gdalraster_runtime(
    activate_runtime = TRUE,
    gdal_home = gdal_home,
    quiet = TRUE
  )
  testthat::expect_false(ok)
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

testthat::test_that("install_gdal_runtime errors when release fails and no fallback is available", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  testthat::local_mocked_bindings(
    resolve_release_asset = function(...) {
      cli::cli_abort("forced release lookup failure for test")
    },
    .env = asNamespace("gdalraster.windows")
  )

  gdal_home <- withr::local_tempdir()
  testthat::expect_error(
    gdalraster.windows::install_gdal_runtime(
      repo = "jimbrig/gdalraster.windows",
      tag = "latest",
      gdal_home = gdal_home,
      overwrite = TRUE,
      fallback_zip = NULL
    ),
    "Failed to download GDAL runtime from GitHub release"
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

testthat::test_that("verify_gdalraster_runtime returns FALSE when gdalraster is unavailable", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  testthat::local_mocked_bindings(
    has_gdalraster_namespace = function() FALSE,
    .env = asNamespace("gdalraster.windows")
  )

  ok <- gdalraster.windows::verify_gdalraster_runtime(
    activate_runtime = FALSE,
    quiet = TRUE
  )
  testthat::expect_false(ok)
})

testthat::test_that("install_gdalraster calls install.packages with repos = NULL", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  # Intercept install.packages() and capture the repos argument so we can
  # assert it is NULL (required for local-file installation; when repos is
  # non-NULL R looks up the tarball path as a package name and never installs
  # from the file, producing the "not available for this version of R" warning).
  captured_repos <- list()

  gdal_home <- create_gdal_home_fixture()
  lib <- withr::local_tempdir()
  tarball <- withr::local_tempfile(fileext = ".tar.gz")
  file.create(tarball)

  testthat::local_mocked_bindings(
    activate_gdal_runtime = function(...) invisible(list()),
    .env = asNamespace("gdalraster.windows")
  )

  testthat::local_mocked_bindings(
    install.packages = function(pkgs, repos, ...) {
      # c(list(NULL)) appends a NULL element; `[[<-` with NULL would drop it
      captured_repos <<- c(captured_repos, list(repos))
      # Simulate a successful install by creating the package directory.
      dir.create(file.path(list(...)$lib, "gdalraster"), recursive = TRUE, showWarnings = FALSE)
      invisible(NULL)
    },
    .package = "utils"
  )

  gdalraster.windows::install_gdalraster(
    gdal_home = gdal_home,
    lib = lib,
    source_tarball = tarball,
    upgrade = FALSE
  )

  # The local-tarball install.packages() call must use repos = NULL.
  testthat::expect_true(
    any(vapply(captured_repos, is.null, logical(1L))),
    info = "install.packages() must be called with repos = NULL for local tarball installation"
  )
})
