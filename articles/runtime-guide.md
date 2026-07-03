# Runtime Guide

``` r

library(gdalraster.windows)
```

This guide covers how the [GDAL](https://gdal.org/) runtime is located,
activated, and used from day to day: session activation, configuration,
source builds of [`gdalraster`](https://firelab.github.io/gdalraster/),
startup hooks, and embedded-python algorithms. For the build internals
behind the runtime bundle, see the
[Architecture](https://docs.jimbrig.com/gdalraster.windows/articles/architecture.md)
article.

## How the runtime home is resolved

Every helper in this package resolves the runtime location (`gdal_home`)
through the same precedence chain:

1.  `options(gdalraster.windows.gdal_home = "...")`
2.  the `GDALRASTER_WINDOWS_GDAL_HOME` environment variable
3.  the package-managed user data directory
    (`tools::R_user_dir("gdalraster.windows", "data")`)

``` r

# where the active runtime lives
gdalraster.windows::gdal_home()

# point the session at a different runtime (option or env var, not persisted)
gdalraster.windows::configure_gdal_home("D:/gdal/custom-runtime", mode = "option")
```

[`configure_gdal_home()`](https://docs.jimbrig.com/gdalraster.windows/reference/configure_gdal_home.md)
is session-scoped by design — it never writes to profile files or
machine state.

## Session activation

Windows resolves a DLL’s imports at load time, so the bundle’s `bin/`
directory must be discoverable *before* `gdalraster.dll` loads.
[`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
prepares the session:

- prepends `<gdal_home>/bin` to `PATH`
- sets `GDAL_DATA`, `PROJ_LIB`, and `PROJ_DATA` to the bundle’s `share/`
  data trees (GDAL and [PROJ](https://proj.org/) need their runtime data
  for CRS operations)
- prepends `<gdal_home>/python` to `PYTHONPATH` for embedded-python
  algorithms
- preloads `libgdal-*.dll` into the process (when `preload = TRUE`, the
  default), so the DLL is already mapped when `gdalraster` asks for it

All of this is session-scoped: no machine or user environment variables
are modified. When preloading fails — most commonly because a dependency
DLL is missing — activation fails immediately with an informative error
instead of deferring to
[`library(gdalraster)`](https://firelab.github.io/gdalraster/), where
the Windows loader would only report a generic “module could not be
found”.

``` r

gdalraster.windows::activate_gdal_runtime()
#> v gdal runtime activated from C:/Users/you/AppData/Roaming/R/data/R/gdalraster.windows/...
```

[`load_gdal_dll()`](https://docs.jimbrig.com/gdalraster.windows/reference/load_gdal_dll.md)
is a convenience wrapper that activates with `preload = TRUE`:

``` r

gdalraster.windows::load_gdal_dll()
```

## Automatic activation on load

Attaching the package triggers a bootstrap that activates an installed
runtime and prepends the isolated `gdalraster` library to
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html), so in an
already-set-up session this is all you need:

``` r

library(gdalraster.windows)
library(gdalraster)
```

Two options control this behavior:

``` r

# disable the load-time bootstrap entirely
options(gdalraster.windows.auto_bootstrap = FALSE)

# additionally auto-attach gdalraster from the isolated library at load time
options(gdalraster.windows.auto_load_gdalraster = TRUE)
```

## Building gdalraster against the runtime

[`install_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdalraster.md)
downloads (or accepts) a `gdalraster` source tarball from
[firelab/gdalraster](https://github.com/firelab/gdalraster) and builds
it against the bundle’s headers and import library:

``` r

# default: latest source from firelab/gdalraster, into the isolated library
gdalraster.windows::install_gdalraster()

# pin a specific ref, or build from a local tarball
gdalraster.windows::install_gdalraster(ref = "v2.1.0")
gdalraster.windows::install_gdalraster(source_tarball = "C:/tmp/gdalraster_2.1.0.tar.gz")

# pre-install gdalraster's R dependencies from CRAN before the source build
gdalraster.windows::install_gdalraster(upgrade = TRUE)
```

Compile and link flags (`GDAL_HOME`, `PKG_CPPFLAGS`, `PKG_LIBS`) are
applied through a scoped Makevars file via
[`withr::with_makevars()`](https://withr.r-lib.org/reference/with_makevars.html),
and the runtime’s `bin/` and data directories are exposed through scoped
environment variables for the duration of the install. Nothing leaks
into your persistent configuration.

The default destination is an isolated library
(`<user data dir>/library`), so an existing CRAN `gdalraster` is left
untouched. Loading from that isolated library is what
[`load_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/load_gdalraster.md)
does:

``` r

# activates the runtime, prepends the isolated library, attaches gdalraster
gdalraster.windows::load_gdalraster()
```

To make the source build your regular `gdalraster` instead, install it
into your user library — accepting that it replaces whatever
`gdalraster` is there:

``` r

gdalraster.windows::install_gdalraster(lib = .libPaths()[1])
```

## Startup hooks

For sessions that should bootstrap without attaching this package, a
managed `.Rprofile` hook loads the bundled GDAL DLL and prepends the
isolated library at startup:

``` r

# preview the generated code without writing anything
cat(gdalraster.windows::gdal_rprofile_snippet())

# write (or update) the managed block in ~/.Rprofile
gdalraster.windows::add_gdal_rprofile_hook()

# preview the resulting file contents without writing
gdalraster.windows::add_gdal_rprofile_hook(dry_run = TRUE)
```

The hook is wrapped in `# >>> gdalraster.windows hook >>>` /
`# <<< gdalraster.windows hook <<<` markers, guards itself with
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) and an OS
check, and is updated in place on subsequent calls rather than appended
repeatedly.

## Embedded-python algorithms

Some GDAL algorithms
(e.g. [`gdal driver gpkg validate`](https://gdal.org/en/stable/programs/gdal_driver_gpkg_validate.html))
are thin C++ entry points around Python implementations: `libgdal`
embeds a CPython interpreter at first use and imports the pure-python
[`osgeo_utils`](https://github.com/OSGeo/gdal/tree/master/swig/python/gdal-utils)
package. The runtime bundle ships `osgeo_utils` under
`<gdal_home>/python`, version-locked to the built GDAL, and activation
exposes it via `PYTHONPATH`:

``` r

library(gdalraster.windows)
library(gdalraster)

alg <- gdalraster::gdal_alg(cmd = "driver gpkg validate")
alg$setArg("dataset", "path/to/file.gpkg")
alg$setArg("full-check", TRUE)
alg$run()
alg$output()
#> [1] "Checking gpkg_spatial_ref_sys\n...\nValidation succeeded"
```

A `python.exe` must be discoverable on `PATH` for GDAL to embed an
interpreter at all — Rtools’ UCRT64 python works, as does any system
python. The compiled `osgeo` SWIG bindings are deliberately not bundled
(they would pin the bundle to a single CPython ABI); the
python-implemented validators degrade gracefully without them.

## Upgrading the runtime

After a new [GDAL runtime
release](https://github.com/jimbrig/gdalraster.windows/releases),
reinstall the bundle and rebuild `gdalraster` against it — the previous
`gdalraster.dll` is bound to the previous GDAL’s ABI and import names:

``` r

# in a fresh session, before gdalraster is loaded
gdalraster.windows::install_gdal_runtime(overwrite = TRUE)
gdalraster.windows::install_gdalraster()
gdalraster.windows::verify_gdalraster_runtime()
```

Overwriting is refused while `gdalraster` is loaded, because its DLL
pins the runtime files in the current process; restart R first. See the
[Troubleshooting](https://docs.jimbrig.com/gdalraster.windows/articles/troubleshooting.md)
article if deletion still fails.
