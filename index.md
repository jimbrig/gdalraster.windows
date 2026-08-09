# gdalraster.windows

`gdalraster.windows` builds a self-contained
[`gdalraster`](https://firelab.github.io/gdalraster/) package against a
modern GDAL runtime published by this repository.

The installed `gdalraster` vendors GDAL and dependency DLLs, matching
GDAL/PROJ data, and `osgeo_utils`. Later sessions require no activation
helper, `.Rprofile` hook, `PATH` edit, or GDAL environment variables.

## Requirements

- Windows with R.
- [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching R.

## Setup

To install the self-contained build into the regular user library:

``` r

pak::pak("jimbrig/gdalraster.windows")
gdalraster.windows::gdal_setup(user_lib = TRUE)
```

Then, in any fresh session:

``` r

library(gdalraster)
gdalraster::gdal_global_reg_names()
```

The default remains non-destructive and targets an isolated managed
library:

``` r

gdalraster.windows::gdal_setup()
```

Pass `user_lib = TRUE` when plain
[`library(gdalraster)`](https://firelab.github.io/gdalraster/) discovery
is required.

## Status, verification, and updates

``` r

gdalraster.windows::gdal_sitrep(user_lib = TRUE)
gdalraster.windows::gdal_verify(user_lib = TRUE)
gdalraster.windows::gdal_update(user_lib = TRUE)
```

Verification runs in fresh processes and checks:

- the GDAL Algorithm API registry;
- Arrow, Parquet, HDF5, and netCDF drivers;
- GEOS and CRS resolution;
- a first Parquet dataset open; and
- `gdal driver gpkg validate` when embedded Python is ready.

## Offline installation

``` r

gdalraster.windows::gdal_setup(
  user_lib = TRUE,
  local_zip = "C:/Downloads/gdal-bundle-v3.13.2-windows-x64.zip"
)
```

Bundle assets are published at
<https://github.com/jimbrig/gdalraster.windows/releases>.

## Design

The package uses the downloaded bundle as a build-time SDK. After
compiling `gdalraster`, it stages and vendors:

``` text
gdalraster/
  libs/x64/                  # gdalraster.dll + GDAL dependency closure
  gdal/                      # matching GDAL data
  proj/                      # matching PROJ data
  python/osgeo_utils/        # embedded-Python algorithms
  gdalraster.windows-build.dcf
```

The SDK has its own `MANIFEST.dcf`. Comparing bundle tags lets
[`gdal_sitrep()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_sitrep.md)
detect a stale build after a runtime update.

Embedded Python is provisioned through a managed `.pth` in system
CPython’s `site-packages`; the package never sets `PYTHONPATH`.

## Repository responsibilities

- `.github/workflows/build.yml`, `tools/build_gdal.sh`, and
  `tools/collect_dlls.sh` build and publish the GDAL bundle.
- The R package installs the SDK, builds and vendors `gdalraster`,
  provisions Python, and verifies the user workflow.
- `.github/workflows/e2e.yml` proves fresh-session self-containment.
- `.github/workflows/edge-cases.yml` exercises dirty-machine failure
  modes.

See the published [Getting
Started](https://docs.jimbrig.com/gdalraster.windows/articles/getting-started.html),
[Runtime
Guide](https://docs.jimbrig.com/gdalraster.windows/articles/runtime-guide.html),
[Architecture](https://docs.jimbrig.com/gdalraster.windows/articles/architecture.html),
and
[Troubleshooting](https://docs.jimbrig.com/gdalraster.windows/articles/troubleshooting.html)
articles for details.
