# Troubleshooting

## Start with the sitrep

``` r

gdalraster.windows::gdal_sitrep(user_lib = TRUE)
gdalraster.windows::gdal_verify(user_lib = TRUE)
```

Omit `user_lib = TRUE` for the default isolated installation. The sitrep
reports runtime and build manifests, staleness, Python readiness,
competing GDAL DLLs, already loaded modules, legacy profile hooks, and
foreign `gdalraster` packages.

## `library(gdalraster)` cannot find the package

The non-destructive default installs into a package-managed isolated
library. Either load from that location or rebuild into the regular user
library:

``` r

gdalraster.windows::gdal_setup(user_lib = TRUE)
library(gdalraster)
```

## `LoadLibrary` reports a missing module

A self-contained build must contain `gdalraster.dll`, `libgdal-*.dll`,
and the full dependency closure in the same `libs/x64` directory:

``` r

package_dir <- find.package("gdalraster")
list.files(file.path(package_dir, "libs", "x64"), pattern = "\\.dll$")
```

Run
[`gdal_update()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_update.md)
to rebuild and re-vendor from a complete bundle. Do not add Rtools or
another GDAL to `PATH` as a repair; that defeats package isolation.

## Empty Algorithm API or missing drivers

[`gdal_verify()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_verify.md)
requires:

- a non-empty
  [`gdal_global_reg_names()`](https://firelab.github.io/gdalraster/reference/gdal_cli.html)
  result;
- Arrow, Parquet, HDF5, and netCDF drivers;
- GEOS and EPSG:4326 resolution; and
- a successful first Parquet open in a fresh process.

If it fails, compare the runtime and build tags in
[`gdal_sitrep()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_sitrep.md).
A mismatch requires
[`gdal_update()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_update.md).
A matching build with missing drivers indicates a bundle regression and
should be reported with the verification output.

## Another GDAL is installed

GDAL executables from pixi, conda, OSGeo4W, Rtools, or MSYS2 may remain
on the machine. The package’s `libs/x64` directory controls dependency
resolution while `gdalraster.dll` loads.

An identically named `libgdal` already loaded in the process is
different: Windows can reuse it by module name. Restart R, load
`gdalraster` first, and inspect
[`gdal_sitrep()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_sitrep.md)
for the loaded module path.

## Legacy `.Rprofile` hooks

Version 0.4.0 removes activation and profile-hook APIs. Delete blocks
marked:

``` text
# >>> gdalraster.windows hook >>>
...
# <<< gdalraster.windows hook <<<
```

Also remove personal code that calls `load_gdal_dll()`,
`activate_gdal_runtime()`, or edits GDAL-related environment variables.
Rebuild once with
[`gdal_setup()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_setup.md)
after cleanup.

## Locked runtime directory

Windows cannot delete mapped DLLs. `gdal_install_runtime(force = TRUE)`
first tries normal deletion, then moves remaining files into a sibling
directory named `<gdal_home>.stale-<pid>-<timestamp>`. Later installs
remove stale directories after locks disappear.

If move-aside also fails, another process holds the file without delete
sharing. Close other R sessions and File Explorer previews. PowerToys
File Locksmith or Resource Monitor can identify the holder.

## Locked `gdalraster` package

The builder stages the complete replacement before touching the
installed package. If the destination DLL is locked, replacement aborts
and leaves the old package unchanged. Restart R, ensure `gdalraster` is
not loaded in another session, then rerun the build.

## Embedded Python is unavailable

[`gdal_sitrep()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_sitrep.md)
reports whether the managed `gdalraster-windows-osgeo-utils.pth` points
at the current vendored `gdalraster/python` directory.

For a regular user-library build use:

``` r

gdalraster.windows::gdal_enable_python(lib = .libPaths()[1])
```

When no system CPython is available, core GDAL functionality remains
ready, but Python-backed algorithms such as `driver gpkg validate`
cannot run.

## Offline and proxy-restricted installation

Transfer a published bundle zip and pass it directly:

``` r

gdalraster.windows::gdal_setup(
  local_zip = "C:/Downloads/gdal-bundle-v3.13.2-windows-x64.zip"
)
```

The installer preserves an embedded manifest when present and otherwise
stamps provenance from the requested release information.
