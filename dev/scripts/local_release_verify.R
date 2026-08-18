# non-interactive local verification for 0.5.0 + gdal-v3.13.2
options(warn = 1)
stopifnot(!interactive())

library(gdalraster.windows)

cat("== gdal_setup(tag=gdal-v3.13.2) ==\n")
gdal_setup(
  tag = "gdal-v3.13.2",
  force = TRUE,
  update = TRUE,
  verify = TRUE
)

cat("== sitrep ==\n")
print(gdal_sitrep(network = FALSE))

cat("== fresh-session functional checks ==\n")
script <- tempfile(fileext = ".R")
writeLines(
  c(
    "stopifnot(!interactive())",
    "library(gdalraster)",
    "ver <- gdalraster::gdal_version()[[1]]",
    "cat('GDAL:', ver, '\n')",
    "stopifnot(grepl('3\\\\.13\\\\.2', ver))",
    "algs <- gdalraster::gdal_global_reg_names()",
    "cat('algorithms:', length(algs), '\n')",
    "stopifnot(length(algs) > 0L)",
    "fmts <- gdalraster::gdal_formats()$short_name",
    "for (d in c('Arrow', 'Parquet', 'HDF5', 'netCDF')) {",
    "  stopifnot(any(grepl(d, fmts, ignore.case = TRUE)))",
    "  cat('driver ok:', d, '\n')",
    "}",
    "stopifnot(isTRUE(gdalraster::has_geos()))",
    "stopifnot(nzchar(gdalraster::srs_to_wkt('EPSG:4326')))",
    "fixture <- system.file('extdata', 'smoke.parquet', package = 'gdalraster.windows')",
    "stopifnot(nzchar(fixture), file.exists(fixture))",
    "pq <- tempfile(fileext = '.parquet')",
    "file.copy(fixture, pq, overwrite = TRUE)",
    "layers <- gdalraster::ogr_ds_layer_names(pq)",
    "cat('parquet layers:', paste(layers, collapse = ','), '\n')",
    "stopifnot(length(layers) >= 1L)",
    "gpkg <- tempfile(fileext = '.gpkg')",
    "gdalraster::ogr_ds_create(",
    "  format = 'GPKG', dsn = gpkg, layer = 'points',",
    "  geom_type = 'Point', fld_name = 'id', fld_type = 'OFTInteger',",
    "  return_obj = FALSE",
    ")",
    "validator <- gdalraster::gdal_alg(cmd = 'driver gpkg validate')",
    "validator$setArg('dataset', gpkg)",
    "validator$setArg('full-check', TRUE)",
    "stopifnot(isTRUE(validator$run()))",
    "cat('gpkg validate: ok\n')",
    "cat('FUNCTIONAL_OK\n')"
  ),
  script
)
status <- system2(
  file.path(R.home("bin"), "Rscript.exe"),
  args = c("--vanilla", script)
)
stopifnot(identical(as.integer(status), 0L))

cat("== TLS-noisy first parquet open ==\n")
tls <- tempfile(fileext = ".R")
writeLines(
  c(
    "stopifnot(!interactive())",
    "for (pkg in c('httpuv', 'later', 'gifski', 'nanoparquet')) {",
    "  if (!requireNamespace(pkg, quietly = TRUE)) {",
    "    utils::install.packages(pkg, repos = 'https://cloud.r-project.org')",
    "  }",
    "  loadNamespace(pkg)",
    "}",
    "stopifnot(all(c('httpuv', 'later', 'gifski', 'nanoparquet') %in% names(getLoadedDLLs())))",
    "pq <- tempfile(fileext = '.parquet')",
    "nanoparquet::write_parquet(data.frame(id = 1L, value = 'tls'), pq)",
    "library(gdalraster)",
    "layers <- gdalraster::ogr_ds_layer_names(pq)",
    "stopifnot(length(layers) == 1L)",
    "cat('TLS_NOISY_OK algorithms=', length(gdalraster::gdal_global_reg_names()), '\n', sep = '')"
  ),
  tls
)
tls_status <- system2(
  file.path(R.home("bin"), "Rscript.exe"),
  args = c("--vanilla", tls)
)
stopifnot(identical(as.integer(tls_status), 0L))

cat("== LOCAL_RELEASE_VERIFY_OK ==\n")
