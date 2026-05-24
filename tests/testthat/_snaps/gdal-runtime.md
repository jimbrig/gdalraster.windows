# load_gdalraster fails clearly when isolated lib missing package

    Code
      gdalraster.windows::load_gdalraster(lib = lib, gdal_home = gdal_home, quiet = TRUE)
    Condition
      Error:
      ! No gdalraster install found in `lib`.
      i Run `gdalraster.windows::install_gdalraster()` first.

