pak::pak("jimbrig/gdalraster.windows")
gdalraster.windows::install_gdal_runtime(overwrite = TRUE)
gdalraster.windows::install_gdalraster()
gdalraster.windows::load_gdalraster()
gdalraster::gdal_version() # expect 3.13.1, released 2026-06-05
gdalraster::gdal_global_reg_names()
gdalraster.windows::verify_gdalraster_runtime()
