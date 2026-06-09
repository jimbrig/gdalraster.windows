# Configure GDAL home for current session

Sets GDAL home for this session using either an R option or environment
variable. This does not write to user profile files.

## Usage

``` r
configure_gdal_home(path, mode = c("option", "env"))
```

## Arguments

- path:

  GDAL home directory path.

- mode:

  Either `"option"` or `"env"`.

## Value

Invisibly returns the normalized GDAL home path.
