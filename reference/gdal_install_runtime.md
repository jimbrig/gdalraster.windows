# Install a self-contained GDAL build runtime

Installs a release bundle used to compile
[`gdal_build_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_build_gdalraster.md).
The installed runtime is a build-time SDK; packages produced by
[`gdal_build_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_build_gdalraster.md)
vendor everything needed at run time.

## Usage

``` r
gdal_install_runtime(
  repo = .bundle_repo,
  tag = "latest",
  asset_pattern = .bundle_asset_pattern,
  gdal_home = default_gdal_home(),
  force = FALSE,
  local_zip = NULL,
  fallback_zip = NULL
)
```

## Arguments

- repo:

  GitHub repository that publishes bundle releases.

- tag:

  Bundle release tag or `"latest"`.

- asset_pattern:

  Regular expression selecting a bundle zip asset.

- gdal_home:

  Destination runtime directory.

- force:

  Reinstall an existing runtime.

- local_zip:

  Optional local bundle zip. This takes precedence over a release
  download.

- fallback_zip:

  Optional local zip used if release resolution or download fails.

## Value

Invisibly, the installed runtime directory.

## Details

The installer is idempotent. When the requested bundle tag is already
recorded in `MANIFEST.dcf`, installation is skipped unless
`force = TRUE`.
