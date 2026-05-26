# Custom GDAL Runtime on Windows: Streamlining `gdalraster.windows` and Extending to `sf` and `terra`

## Executive Summary

The `gdalraster.windows` package solves a genuine, deep problem: the Rtools45 MXE build of GDAL historically omitted `muparser` and shipped with the static-registration bug that left the Algorithm API registry empty. The current implementation is already architecturally sound, but several design decisions leave friction for users and create integration complexity when adding `sf` and `terra`. This report synthesizes grounded reality — the actual `Makevars.ucrt` files in both packages, the Windows DLL loader semantics, and the upstream GDAL fix trajectory — to provide actionable guidance on streamlining the existing solution and extending it correctly.[^1][^2][^3][^4]

***

## Part 1: The Present State of the Ecosystem

### Upstream GDAL Fix and Its Implications

The bug that motivated `gdalraster.windows` — static algorithm self-registration being dead-stripped by the MXE static-archive linker — was patched upstream in GDAL 3.12.2 via a PR that explicitly links registration objects. The next Rtools UCRT64 revision targeting GDAL 3.13.x is expected to carry both this fix and `muparser`. This matters for scoping: once that Rtools release lands, the CRAN binary of `gdalraster` will work correctly for the Algorithm API *without* the custom bundle. However, `gdalraster.windows` retains ongoing value beyond the bug fix:[^2][^1]

- It pins a user-controlled GDAL version independently of Rtools release cadence
- It enables drivers (Arrow, Parquet, HDF5, NetCDF) that the lean MXE build may not compile in
- It provides a reproducible pipeline for any downstream custom GDAL feature requirement
- It can serve as the single shared GDAL runtime for `sf` and `terra` in the same session

The package should therefore be repositioned in its README and documentation from "workaround for issue #826" to "custom GDAL feature-set manager for Windows R spatial workflows."

### What the CRAN Binaries for sf and terra Actually Bundle

Both `sf` (CRAN) and `terra` (CRAN) on Windows ship as pre-compiled binaries that statically link against the Rtools UCRT64 sysroot at CRAN build time. The `Makevars.ucrt` for both packages is identical in structure:

```makefile
ifeq (,$(shell pkg-config --version 2>/dev/null))
  PKG_LIBS = -fopenmp -lgdal ... [~50 static Rtools libs] ... -lproj -lsqlite3 ...
else
  PKG_LIBS = $(shell pkg-config --libs gdal geos proj)
endif

all: clean winlibs

winlibs:
    cp -r "$(R_TOOLS_SOFT)/share/gdal" ../inst/
    cp -r "$(R_TOOLS_SOFT)/share/proj" ../inst/
```



The `ifeq` block checks whether `pkg-config` is available. At CRAN build time on the Windows builder, `pkg-config` is not on the PATH in the standard Rtools environment, so the `ifeq` branch fires and the packages link against Rtools' 50-library static list. The `winlibs:` target copies GDAL and PROJ data files from the Rtools sysroot (`R_TOOLS_SOFT`) directly into each package's `inst/` directory, making the CRAN binaries fully self-contained — they do not require any system GDAL to be present at runtime. This is why `sf` "just works" on a stock Windows R install with no external libraries.

The key insight is that `terra` adds one extra element in the `pkg-config` branch that the `ifeq` branch lacks:

```makefile
else
  PKG_LIBS = $(shell pkg-config --libs gdal geos proj)
  PKG_LIBS += -ltbb12
  PKG_CXXFLAGS += -DHAVE_TBB
endif
```

This means a source-rebuild of `terra` against a custom GDAL using the `pkg-config` path will try to link against `libtbb12`. This library must either be in the bundle or provided separately — Intel TBB is available in UCRT64 (`ucrt64/lib/libtbb12.dll.a`) and would need to be included in `collect_dlls.sh`'s sweep.

***

## Part 2: The Windows DLL Conflict Problem in Precise Terms

### How Windows Resolves DLL Identity

Windows' `LdrpLoadLibrary` identifies a DLL by its module name (filename only, case-insensitive), not its full path. The first call to `LoadLibrary("libgdal-39.dll")` maps the file into the process's virtual address space and creates an entry in the loaded module list keyed by `"libgdal-39.dll"`. Any subsequent `LoadLibrary("libgdal-39.dll")` — regardless of whether the DLL is in a different directory — simply increments the reference count on the already-loaded module and returns the same handle. There is no process-level equivalent of Linux `RTLD_LOCAL` that would create an independent copy.[^3][^4]

This creates a strict constraint: **in any R session that loads both `gdalraster` (from the custom bundle) and `sf`/`terra` (CRAN binaries), there can only be one active `libgdal-39.dll` in memory.** The one that wins is whichever package gets `dyn.load`-ed first.

There is one partial escape hatch: loading a DLL by its *full absolute path* via `LoadLibrary` can force a separate mapping if the filenames differ. Two DLLs with the same filename but in different directories cannot coexist unless copied and renamed. This is not a practical approach for R package integration.[^5][^6]

### The Safe DLL Search Order

When `dyn.load(dll_path, local=FALSE, now=TRUE)` is called with a full absolute path (as `activate_gdal_runtime()` does), Windows maps that specific file. The subsequent implicit loads triggered by `library(sf)` will call `LoadLibrary("libgdal-39.dll")` *without* a full path; the loader will then check the already-loaded module list first. If the custom bundle's `libgdal-39.dll` was already loaded by the explicit path call, the loader returns the already-mapped module — and `sf` runs against the custom GDAL.[^4]

This means the activation-first ordering in `activate_gdal_runtime()` is not merely a best practice — it is the *only* mechanism by which CRAN binary `sf`/`terra` can be coerced to use the custom GDAL at runtime.

### Dependency DLL Resolution After Load

A subtlety documented in MSDN and confirmed by Windows loader research: when the loader resolves a DLL's *import dependencies* (the DLLs listed in its import address table), it uses the DLL search order based on the *calling process's* current search path at the time the parent DLL is loaded, not the path of the parent DLL itself. This means that even if `libgdal-39.dll` is loaded from `C:\Users\Jimmy\AppData\Local\gdalraster.windows\bin\`, its own dependencies (e.g., `libproj-*.dll`, `libgeos_c-*.dll`) will be searched via the standard DLL search order: application directory → system directories → `PATH`.[^7][^4]

This is why `activate_gdal_runtime()` prepending `bin/` to `PATH` *before* the `dyn.load()` call is architecturally correct: at the moment the loader resolves `libgdal-39.dll`'s transitive dependencies, the bundle's `bin/` directory is already first on `PATH`.

***

## Part 3: Streamlining the Current gdalraster.windows Implementation

### The `--allow-multiple-definition` Flag

The current `install_gdalraster()` passes `-Wl,--allow-multiple-definition` in `PKG_LIBS`. This is a linker flag that suppresses duplicate symbol errors — a red flag that indicates two or more object files or archives in the link define the same symbol. This almost certainly arises from symbol overlap between the custom bundle's `libgdal.dll.a` import library and residual static archives from Rtools that get pulled in by gdalraster's own transitive dependencies.

The correct fix is to ensure the import library provided to the linker comes *only* from the custom bundle, with no Rtools static archives for GDAL or GDAL-linked libraries mixed in. This can be achieved by explicitly controlling the library search path order: `-L"$(GDAL_HOME)/lib" -lgdal` with no `-L$(R_TOOLS_SOFT)/lib` before it. If Rtools' GDAL `.a` files are still being found, adding `-L` for the bundle path *and* using `-Wl,--no-undefined` would make the linker error visibly on what symbol is truly duplicated, so it can be resolved rather than suppressed.

### The DLL Version Hardcode in `build_gdal.sh`

The verification step `ls -lh "${INSTALL_DIR}/bin/libgdal-39.dll"` hardcodes the SONAME version `39`. When GDAL bumps its SONAME (which happens on major API version changes), this will produce a silent false negative — the script will exit with an error about a missing file even though the build succeeded and produced `libgdal-40.dll`. The fix is straightforward: use `libgdal-*.dll` as the glob pattern, consistent with how the rest of the codebase already matches DLL names.

### Session Startup Sequencing

The current `.onLoad` / `startup_bootstrap()` approach in `zzz.R` runs `activate_gdal_runtime()` followed by `load_gdalraster()` automatically when `auto_bootstrap` is enabled. This is correct but has a subtle ordering problem: if `sf` or `terra` is already loaded *before* `library(gdalraster.windows)` is called (common in scripts that do `library(sf); library(gdalraster.windows)`), the custom GDAL's DLL loses the race — `sf`'s import of `libgdal-N.dll` from Rtools' embedded copy has already won.

The recommended fix is to document prominently (and enforce with a warning) that `library(gdalraster.windows)` must be the *first* spatial package loaded in the session. This could be implemented as a check in `activate_gdal_runtime()`:

```r
already_loaded <- any(c("sf", "terra") %in% loadedNamespaces())
if (already_loaded) {
  cli::cli_warn(c(
    "!" = "sf or terra was loaded before gdalraster.windows.",
    "i" = "The custom GDAL runtime may not be active for those packages.",
    "i" = "Restart R and load gdalraster.windows first."
  ))
}
```

### The `.Rprofile` Hook Approach

The managed marker block in `startup_hook.R` (`add_gdal_rprofile_hook()`) is the right way to handle persistent session setup. However, there is a race condition if the user's `.Rprofile` also loads `sf` (via `library(sf)` or through another package's `.Rprofile` hook) before the `gdalraster.windows` hook runs. R processes `.Rprofile` line by line, so hook ordering matters. The hook should be written to execute as early as possible in `.Rprofile`, and documentation should advise users to place the `gdalraster.windows` hook before any other spatial package calls.

***

## Part 4: Extending to sf and terra — The Full Landscape

### Three Integration Models

There are three distinct ways `sf` and `terra` can coexist with the custom GDAL bundle, each with different correctness guarantees:

| Model | How it works | DLL conflict risk | Effort | Recommended for |
|-------|-------------|------------------|--------|-----------------|
| **Runtime-only coexistence** | CRAN binaries + activation-first ordering | Low (if ordering held) | None | Casual use, read-only operations |
| **Source rebuild against bundle** | `install_sf()` / `install_terra()` wrappers in `gdalraster.windows` | None | High | Production workflows needing Arrow/Parquet drivers in sf/terra |
| **Pixi/conda-forge unified environment** | All packages built by conda-forge against the same GDAL | None (separate namespace) | Medium | Cross-platform reproducibility |

### Model 1: Runtime-Only Coexistence

For users who load CRAN binary `sf`/`terra` alongside the custom `gdalraster`, the only requirement is the ordering guarantee: `activate_gdal_runtime()` and `dyn.load(dll_path)` must complete before any `library(sf)` or `library(terra)` call. Under this model, `sf` and `terra` will use the custom GDAL at runtime for all file I/O and geometry operations, but the binary was compiled against Rtools' GDAL, meaning:

- Arrow/Parquet read capabilities in `sf::st_read()` will not be available (the binary wasn't compiled with those drivers)
- The GDAL version seen at runtime (`sf::sf_extSoftVersions()`) may report the custom version, but driver availability is determined at compile time
- This is functionally safe for everything except driver-specific features not in the Rtools build

This is the lowest-friction path and appropriate for most use cases once the upstream Rtools GDAL version catches up.

### Model 2: Source Rebuild — Architecture and Key Differences

An `install_sf()` function in `gdalraster.windows` would follow the same `withr::with_makevars` / `withr::with_envvar` pattern as `install_gdalraster()`. However, both `sf` and `terra`'s `Makevars.ucrt` introduce complications that do not exist for `gdalraster`:

**The `pkg-config` branch gating.** Both packages' `Makevars.ucrt` only use the clean `pkg-config --libs gdal geos proj` flag generation if `pkg-config` is available on `PATH`. In the standard Rtools45 environment, `pkg-config` is absent. The MSYS2 UCRT64 package `mingw-w64-ucrt-x86_64-pkg-config` provides it and it is present in MSYS2 shells, but when the source install runs inside an R process via `withr::with_envvar`, `pkg-config` will only be visible if the MSYS2 `bin/` path is in `PATH` at that moment.

The correct approach is to either:
1. Add the MSYS2 `bin/` to `PATH` in the `withr::with_envvar` scope, or
2. Explicitly set `R_TOOLS_SOFT` in the scoped environment to point at the custom bundle root, so the `ifeq` branch fires but `winlibs:` copies data from the bundle rather than Rtools

Option 2 is architecturally cleaner because it avoids the `pkg-config` dependency and means the `~50 static lib` list in the `ifeq` branch is used — but those 50 libraries must actually exist in the bundle's `lib/` directory as `.a` files for the link to succeed. This makes it essential that `build_gdal.sh` produces matching static archives for every library in that list.

**The `winlibs:` data copy.** Both `sf` and `terra` have an unconditional `winlibs:` target that does `cp -r "$(R_TOOLS_SOFT)/share/gdal" ../inst/` and `cp -r "$(R_TOOLS_SOFT)/share/proj" ../inst/`. This is the mechanism by which `sf` and `terra` bundle GDAL and PROJ data files inside the package installation, making them self-contained. If `R_TOOLS_SOFT` is overridden to the bundle's root, this will copy the bundle's `share/gdal/` and `share/proj/` into each package's `inst/`, which is the correct desired behavior — each package carries its own copy of the data from the same source.

The `install_sf()` wrapper therefore needs to set `R_TOOLS_SOFT` in `Makevars` so the `winlibs:` target resolves correctly:

```r
makevars <- c(
  R_TOOLS_SOFT = gdal_home,           # → winlibs: copies share/gdal, share/proj from bundle
  PKG_CPPFLAGS = paste0('-DHAVE_PROJ_H -I"', file.path(gdal_home, "include"), '"'),
  PKG_LIBS     = paste0('-L"', file.path(gdal_home, "lib"), '" -lgdal -lgeos_c -lproj ...')
)
```

**TBB requirement for terra.** The `pkg-config` branch in `terra`'s `Makevars.ucrt` adds `-ltbb12` and `-DHAVE_TBB`. The `ifeq` branch does not include TBB (there is a commented-out `-ltbb_static` line), meaning a source rebuild using the `ifeq` path will compile without TBB parallelism. This is a functionally acceptable trade-off: `terra` works without TBB, just without multithreaded raster operations. Alternatively, `libtbb12` from UCRT64 can be bundled alongside the GDAL bundle and added to `PKG_LIBS`.

**GEOS dependency.** Both `sf` and `terra` link against `libgeos_c` and `libgeos`, which must be provided by the bundle. GDAL itself depends on GEOS and includes it in its own link graph, but the `.a` file must also be available at `gdal_home/lib/libgeos_c.a` and `libgeos.a` for `sf`'s and `terra`'s compiler invocations to succeed.

### The `HAVE_PROJ_H` Flag for sf

`sf`'s `Makevars.ucrt` hardcodes `-DHAVE_PROJ_H` in `PKG_CPPFLAGS` regardless of the `ifeq`/`else` branch. This flag signals that PROJ's C API header (`proj.h`, the modern API, as opposed to the deprecated `projects.h`) is present. When performing a source rebuild, this flag must remain in the `PKG_CPPFLAGS` passed via `withr::with_makevars`. If the bundle's PROJ include directory provides `proj.h` (it will if PROJ >= 6 was used, which is the case for any modern GDAL build), this flag will be correct.

### The s2 Geometry Dependency

`sf` uses the `s2` R package for geodetic geometry operations on long/lat coordinates by default (since sf 1.0). `s2` has its own compiled C++ code that bundles Google's S2 geometry library directly and does *not* link against GDAL at all. This means `s2` is immune to the DLL conflict problem — it can be installed from CRAN as a binary without any interaction with the custom GDAL bundle.[^8]

### Model 3: Pixi/conda-forge Unified Environment

The cleanest theoretical solution — and the one that already works for your Linux WSL setup — is using `pixi` or `conda-forge` to manage a unified environment where GDAL, `r-sf`, `r-terra`, and `r-gdalraster` are all built by conda-forge against the same `libgdal` package. On Windows, this means running R through the pixi/conda environment rather than standalone Rtools R.[^9]

The `conda-forge` channel provides `r-gdalraster` binaries and builds `r-sf` and `r-terra` via `r-spatial` feedstocks — all against the same conda-forge GDAL. There is no DLL conflict because all packages are compiled against the same shared library; `libgdal-arrow-parquet` can be installed as a plugin.[^10][^9]

The trade-off is that running R through a conda/pixi environment on Windows requires either the conda command-line environment or a conda-aware IDE configuration, which diverges from the standard "open RStudio, install from CRAN" workflow. For a consulting engineering context, this may or may not be acceptable depending on whether end-users need to reproduce the environment.

***

## Part 5: Recommended Implementation Roadmap

### Immediate: Streamlining What Exists

1. **Remove `--allow-multiple-definition`** from `install_gdalraster()`. Add a diagnostic that identifies the duplicate symbols (`-Wl,--warn-duplicate-common`) and fix the root cause by ensuring no Rtools GDAL archives contaminate the link.

2. **Fix the hardcoded DLL version check** in `build_gdal.sh` from `libgdal-39.dll` to `libgdal-*.dll`.

3. **Add an early warning in `activate_gdal_runtime()`** if `sf` or `terra` namespaces are already loaded, directing users to restart R and load the custom runtime first.

4. **Expose a `gdal_runtime_info()` function** (similar to `sf::sf_extSoftVersions()`) that returns the active GDAL version, build drivers, muparser availability, and Arrow/Parquet status as a named list. This gives users immediate diagnostic information.

5. **Add the `.Rprofile` hook ordering note** to documentation: the `gdalraster.windows` hook must appear before any other spatial package calls in `.Rprofile`.

### Near-Term: sf and terra Integration

6. **Implement `install_sf()` and `install_terra()` wrapper functions** using the `withr::with_makevars` + `withr::with_envvar` pattern, setting `R_TOOLS_SOFT` to the bundle root so the `winlibs:` target copies data correctly. Target the `ifeq` branch path for initial simplicity.

7. **Extend `collect_dlls.sh`** to explicitly check for `libgeos_c-*.dll` and verify it is bundled — currently the `ntldd -R` sweep should pick it up, but an explicit assertion would make failure modes visible in CI.

8. **Bundle `libtbb12.dll`** from UCRT64 in the bundle's `bin/` for `terra` TBB support, and add it to the `collect_dlls.sh` allow-list.

9. **Implement `verify_sf_runtime()` and `verify_terra_runtime()`** smoke tests that check `sf::gdal_version()` and `terra::gdal()` report the expected version number, confirming the source-rebuilt packages are actually using the custom GDAL.

### Longer-Term: CI Integration

10. **Add a Job 3** to the GitHub Actions workflow that performs the `install_sf()` + `install_terra()` source rebuilds using the bundle produced by Job 1, then loads all three packages in the same R session and verifies:
    - `sf::gdal_version()` matches the custom version
    - `terra::gdal()` matches the custom version  
    - `gdalraster::gdal_version()` matches
    - `sf::st_drivers()` includes `Arrow` and `Parquet`
    - `gdalraster::gdal_global_reg_names()` returns non-empty
    - All three packages report consistent GDAL, GEOS, and PROJ versions

This CI job provides the correctness guarantee that is currently impossible to achieve with CRAN binaries.

***

## Part 6: The Linux Parallel and Key Divergence

The pixi-managed GDAL 3.13 approach that works cleanly on WSL differs from the Windows situation in three fundamental ways that explain why the solution is easier on Linux:[^9]

| Property | Linux (ELF) | Windows (PE/COFF) |
|----------|-------------|-------------------|
| Runtime library identity | SONAME embedded in `.so` at link time | Filename only, determined at load time |
| Multiple same-name libs in process | Prevented by SONAME versioning; different SONAMEs coexist | Same filename → one canonical loaded instance regardless of path |
| Preferred search path in binary | `RPATH`/`RUNPATH` embedded at link time | Not supported; PATH-only at runtime |
| sf/terra "own GDAL" installation | installs `libgdal-dev` headers as sysreq, runtime controlled by `LD_LIBRARY_PATH` | Bundles complete static link into package `.dll`, no runtime system dependency |

On Linux, `LD_PRELOAD` or `LD_LIBRARY_PATH` being set before R starts is sufficient to ensure all packages resolve to the pixi GDAL because the ELF dynamic linker evaluates `RPATH`/`RUNPATH` per-library. On Windows, there is no per-library equivalent — the only mechanism is the process-wide `PATH` order at the time each DLL is first `LoadLibrary`-called. The `activate_gdal_runtime()` design correctly handles this by calling `dyn.load(dll_path)` with a full absolute path before any package that would otherwise trigger an implicit `LoadLibrary` for `libgdal-N.dll`.[^9]

***

## Conclusion

The `gdalraster.windows` package is the right approach for the right problem. The core architecture — build a self-contained GDAL bundle in MSYS2 UCRT64, verify it is truly self-contained via `ntldd`, install `gdalraster` from source against it using scoped `Makevars` — is technically correct and robust. The refinements needed are largely about removing the `--allow-multiple-definition` workaround, hardening the activation-ordering guarantee, and extending the pattern to `sf` and `terra`.

The sf/terra extension is feasible via source rebuild with `R_TOOLS_SOFT` override, but requires that the GDAL bundle provides compatible static archives for every library in `sf`/`terra`'s `Makevars.ucrt` link list. For users willing to run R through a pixi/conda-forge environment, Model 3 provides the cleanest multi-package coexistence because conda-forge builds all spatial R packages against its own internally consistent GDAL. The source-rebuild model within `gdalraster.windows` is the right approach for users who need to stay within the standard Rtools R environment while accessing a feature-complete GDAL.[^10][^9]

---

## References

1. [Enable muparser in the RTools build of GDAL (so that ... - GitHub](https://github.com/firelab/gdalraster/issues/858) - Start with a working RTools 4.5, revision 6691, that successfully builds R packages including gdalra...

2. [https://raw.githubusercontent.com/OSGeo/gdal/maste...](https://raw.githubusercontent.com/OSGeo/gdal/master/NEWS.md) - GDAL 3.12.2 is a bugfix release. ## Build * Arrow/Parquet: fix build issue with libarrow 23.0 with p...

3. [What Happens When You Load a Library - Aaron Ballman](https://blog.aaronballman.com/2011/08/what-happens-when-you-load-a-library/) - This explains why loading one library can suddenly pull in several others — they're necessary! After...

4. [DLL Dynamic-Link Library Search Order - IAmAProgrammer - 博客园](https://www.cnblogs.com/shangdawei/p/4056967.html) - An application can also use LOAD_LIBRARY_SEARCH flags with the SetDefaultDllDirectories function to ...

5. [Loading 2 DLLs of the Same Name. - limbioliong - WordPress.com](https://limbioliong.wordpress.com/2012/06/26/loading-2-dlls-of-the-same-name/) - You can use 2 different HMODULEs to obtain 2 function address from 2 different DLLs using the same f...

6. [Multiple LoadLibrary for copies of the same DLL - Stack Overflow](https://stackoverflow.com/questions/38738899/multiple-loadlibrary-for-copies-of-the-same-dll) - I have a DLL which is not thread-safe and must be used by multiple threads. I am not sure how Window...

7. [Understanding the Windows DLL Search Order: A Deep Dive into ...](https://www.akshayjain.blog/post/understanding-the-windows-dll-search-order-a-deep-dive-into-internals-and-security-implications) - Learn the technical workings of Windows DLL search order, its role in system behavior, and how attac...

8. [Simple Features for R • sf - r-spatial](https://r-spatial.github.io/sf/) - Support for simple feature access, a standardized way to encode and analyze spatial vector data. Bin...

9. [Download — GDAL documentation](https://gdal.org/en/stable/download.html) - The GDAL project distributes GDAL as source code and Containers only. Binaries produced by others ar...

10. [r-gdalraster - conda-forge - Anaconda.org](https://anaconda.org/conda-forge/r-gdalraster) - Install r-gdalraster with Anaconda.org. API bindings to the Geospatial Data Abstraction Library ('GD...

