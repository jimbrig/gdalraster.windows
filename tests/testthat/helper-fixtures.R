create_bundle_fixture <- function(root, tag = "gdal-v9.9.1") {
  dirs <- c(
    file.path(root, "bin"),
    file.path(root, "include"),
    file.path(root, "lib"),
    file.path(root, "share", "gdal"),
    file.path(root, "share", "proj"),
    file.path(root, "python", "osgeo_utils", "samples")
  )
  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
  writeLines("dll", file.path(root, "bin", "libgdal-39.dll"))
  writeLines("dependency", file.path(root, "bin", "zlib1.dll"))
  writeLines("header", file.path(root, "include", "gdal.h"))
  writeLines("import", file.path(root, "lib", "libgdal.dll.a"))
  writeLines("data", file.path(root, "share", "gdal", "header.dxf"))
  writeLines("proj", file.path(root, "share", "proj", "proj.db"))
  writeLines("", file.path(root, "python", "osgeo_utils", "__init__.py"))
  writeLines("", file.path(root, "python", "osgeo_utils", "samples", "validate_gpkg.py"))
  gdalraster.windows:::write_manifest(
    gdalraster.windows:::bundle_manifest(
      tag = tag,
      gdal_version = sub("^gdal-v", "", tag),
      asset_name = "fixture.zip"
    ),
    file.path(root, "MANIFEST.dcf")
  )
  root
}

create_bundle_zip <- function(path, tag = "gdal-v9.9.1") {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  bundle <- create_bundle_fixture(file.path(root, "bundle"), tag = tag)
  old <- setwd(dirname(bundle))
  withr::defer(setwd(old), envir = parent.frame())
  utils::zip(path, files = basename(bundle))
  path
}

release_fixture <- function(tag, assets = list(), draft = FALSE, prerelease = FALSE) {
  list(tag_name = tag, draft = draft, prerelease = prerelease, assets = assets)
}

asset_fixture <- function(id, name, url) {
  list(id = id, name = name, browser_download_url = url)
}
