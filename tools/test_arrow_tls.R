gdal_home <- Sys.getenv("GDAL_TLS_HOME", unset = "")
gdalraster_lib <- Sys.getenv("GDALRASTER_TLS_LIB", unset = "")

stopifnot(nzchar(gdal_home), dir.exists(gdal_home))
stopifnot(nzchar(gdalraster_lib), dir.exists(gdalraster_lib))
stopifnot(!"gdalraster" %in% loadedNamespaces())

for (package in c("httpuv", "later", "gifski", "nanoparquet")) {
  base::loadNamespace(package)
}

loaded_dlls <- names(getLoadedDLLs())
required_dlls <- c("httpuv", "later", "gifski", "nanoparquet")
stopifnot(all(required_dlls %in% loaded_dlls))

parquet_path <- tempfile(fileext = ".parquet")
nanoparquet::write_parquet(data.frame(id = 1L, value = "tls-regression"), parquet_path)

gdalraster.windows::load_gdalraster(
  lib = gdalraster_lib,
  gdal_home = gdal_home,
  quiet = TRUE
)

layers <- gdalraster::ogr_ds_layer_names(parquet_path)
stopifnot(length(layers) == 1L)

cli::cli_alert_success(
  "first Parquet open passed after loading httpuv, later, gifski, and nanoparquet"
)
