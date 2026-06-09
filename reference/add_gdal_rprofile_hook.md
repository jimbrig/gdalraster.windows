# Add or update an .Rprofile hook for bundled GDAL

Writes a managed hook block into an `.Rprofile` file. The block loads
the bundled GDAL DLL before package attach and prepends the custom
gdalraster library path.

## Usage

``` r
add_gdal_rprofile_hook(
  rprofile = "~/.Rprofile",
  gdal_home = default_gdal_home(),
  lib = default_gdalraster_lib(),
  dry_run = FALSE
)
```

## Arguments

- rprofile:

  Target `.Rprofile` path.

- gdal_home:

  GDAL home directory.

- lib:

  Library path containing the custom gdalraster install.

- dry_run:

  If `TRUE`, return the updated file contents without writing.

## Value

Invisibly returns the updated `.Rprofile` text.
