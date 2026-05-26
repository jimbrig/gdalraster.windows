# toolchain and abi notes

This document explains the technical details behind this project:

- why Windows toolchain alignment matters
- what the build flags in this repo do
- why runtime loading needs explicit handling

It is written as a practical reference for maintainers.

## terms used in this repository

### mingw-w64

`mingw-w64` is the GCC-based Windows toolchain used to compile native
`*.exe`/`*.dll` binaries against Win32 APIs.

### msys2

MSYS2 provides:

- package management (`pacman`)
- shell/tooling environment
- mingw-w64 toolchain variants (`UCRT64`, `MINGW64`, etc.)

In this project, MSYS2 is the build environment. It is not the runtime target.

### rtools45

Rtools45 is the Windows build toolchain used by R packages on Windows.
It is UCRT-based and compatible with the UCRT64 model used in this repo.

### ucrt

UCRT is the Universal C Runtime from Microsoft. Rtools45 and this repo's
UCRT64 builds use it to stay ABI-compatible at runtime.

## why this project is necessary

`gdalraster` relies on GDAL functionality that has historically not always been
reliable in every Windows toolchain state.

The issue pattern behind this repository:

- package builds may succeed
- runtime may still fail to expose expected algorithm APIs
- or runtime loading fails due to unresolved DLL dependencies

This project addresses those failure modes by controlling both:

1. GDAL build composition
2. runtime bundle closure and activation

## c++ abi and binary compatibility

For this project, the practical rule is:

- build GDAL and `gdalraster` with compatible MinGW/UCRT toolchains

Why:

- C++ ABI details (name mangling, exception unwinding, object layout) can break
  across incompatible compiler/runtime combinations.
- even when symbols resolve, mismatched ABI can produce fragile runtime
  behavior.

This is why the repo emphasizes source-building `gdalraster` against the same
runtime bundle it later loads.

## build flags used in `tools/build_gdal.sh`

Current key flags and their intent:

- `-DGDAL_USE_MUPARSER=ON`  
  enables muparser support required by parts of modern GDAL algorithm usage.

- `-DGDAL_USE_ARROW=ON`, `-DGDAL_USE_PARQUET=ON`, `-DGDAL_USE_HDF5=ON`,
  `-DGDAL_USE_NETCDF=ON`, `-DGDAL_USE_GEOS=ON`, `-DGDAL_USE_SPATIALITE=ON`  
  enables optional drivers/features included in this custom runtime profile.

- `-DGDAL_HIDE_INTERNAL_SYMBOLS=ON`  
  reduces exported symbol surface and avoids export-table pressure on Windows.

- `-Wl,--kill-at`  
  adjusts MinGW stdcall export decoration behavior for cleaner export names.

- `-static-libgcc -static-libstdc++`  
  links GCC/C++ runtime libs statically into produced binaries to reduce
  external runtime requirements.

- `-Wl,-Bstatic,--whole-archive -lwinpthread -Wl,-Bdynamic,--no-whole-archive`  
  forces inclusion of required pthread runtime objects while returning to normal
  dynamic behavior for the rest of the link.

## why `collect_dlls.sh` is critical

Building `libgdal-*.dll` is only half the job. Runtime succeeds only when all
transitive non-Windows dependencies are available.

`tools/collect_dlls.sh` does this by:

1. collecting primary GDAL install outputs (`bin`, `include`, `lib`, `share`)
2. recursively inspecting dependencies with `ntldd -R`
3. copying required `/ucrt64` DLLs into bundle `bin/`
4. failing if unresolved non-Windows dependencies remain

This closure check is one of the main safety guarantees in this repository.

## compile-time vs runtime paths

### compile-time

During `install_gdalraster()`, scoped Makevars point compilation to:

- `<gdal_home>/include`
- `<gdal_home>/lib`

### runtime

At session runtime, Windows still needs to locate `libgdal-*.dll` and its
dependencies. `activate_gdal_runtime()` handles this by:

- prepending `<gdal_home>/bin` to `PATH`
- setting `GDAL_DATA`, `PROJ_LIB`, `PROJ_DATA`
- optionally preloading the GDAL DLL via `dyn.load()`

Compile-time success does not guarantee runtime success without this step.

## startup behavior in this package

- `.onLoad` in `R/zzz.R` runs `startup_bootstrap()` by default.
- bootstrap activates runtime (when available) and prepends the managed custom
  library path.
- optional `.Rprofile` hook (`add_gdal_rprofile_hook()`) can persist startup
  behavior.

## upstream references

- [firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826)
- [firelab/gdalraster#858](https://github.com/firelab/gdalraster/issues/858)
- [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982)
- [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592)
- [Rtools45 news](https://cran.r-project.org/bin/windows/Rtools/rtools45/news.html)
