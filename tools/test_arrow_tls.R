# TLS regression gate: load TLS-heavy native modules first, then perform the
# process's first GDAL Parquet open against a vendored self-contained
# gdalraster. Must run under Rscript --vanilla with no prior gdalraster load.

gdalraster_lib <- Sys.getenv("GDALRASTER_TLS_LIB", unset = "")
stopifnot(nzchar(gdalraster_lib), dir.exists(file.path(gdalraster_lib, "gdalraster")))
stopifnot(!"gdalraster" %in% loadedNamespaces())

for (package in c("httpuv", "later", "gifski", "nanoparquet")) {
  base::loadNamespace(package)
}

loaded_dlls <- names(getLoadedDLLs())
required_dlls <- c("httpuv", "later", "gifski", "nanoparquet")
stopifnot(all(required_dlls %in% loaded_dlls))

parquet_path <- tempfile(fileext = ".parquet")
nanoparquet::write_parquet(
  data.frame(id = 1L, value = "tls-regression", stringsAsFactors = FALSE),
  parquet_path
)

library(gdalraster, lib.loc = gdalraster_lib)

algorithms <- gdalraster::gdal_global_reg_names()
stopifnot(length(algorithms) > 0L)

formats <- gdalraster::gdal_formats()$short_name
stopifnot(any(grepl("Parquet", formats, ignore.case = TRUE)))
stopifnot(any(grepl("Arrow", formats, ignore.case = TRUE)))

layers <- gdalraster::ogr_ds_layer_names(parquet_path)
stopifnot(length(layers) == 1L)

cli::cli_alert_success(
  "first Parquet open passed after loading httpuv, later, gifski, and nanoparquet ({length(algorithms)} algorithms)"
)
