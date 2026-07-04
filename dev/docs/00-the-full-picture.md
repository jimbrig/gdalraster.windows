# the full picture

> [!NOTE]
> Start here. This is the narrative that connects everything: what problem
> this project solves, why every major design decision was forced rather
> than chosen, and what guarantees the system provides today. It assumes a
> senior engineer who does not need to know Windows C++ internals up front —
> concepts are introduced when the story needs them, and
> [`08-windows-dll-abi-deep-dive.md`](08-windows-dll-abi-deep-dive.md) has
> the full mechanics when you want them.

## the one-paragraph version

`gdalraster` needs a modern GDAL with the Algorithm API (muparser), which the R toolchain's own GDAL doesn't provide. Because `gdalraster` binds GDAL's **C++** API, and C++ has no cross-compiler binary standard, the GDAL it links must come from the same compiler family as R's Windows toolchain (MinGW/UCRT) — ruling out every convenient prebuilt GDAL (conda, OSGeo4W, vcpkg: all MSVC). So this project builds GDAL from source with MinGW in CI, ships it with its complete DLL closure as a versioned bundle, rebuilds `gdalraster` from source against that bundle on the user's machine, and manages the Windows loader at session startup so the right DLLs resolve. Each of those clauses exists because something broke without it.

## act 1: the original problem (May 2026)

`gdalraster::gdal_global_reg_names()` returned `character(0)` on Windows — the GDAL Algorithm API registry was empty. Two upstream causes:

1. GDAL's algorithm registration uses C++ static constructors, which some static-linking toolchains dead-code-eliminated ([firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826), fixed upstream in GDAL 3.12.2 via [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592)).
2. Rtools' bundled GDAL lacked muparser, which parts of the Algorithm API require.

The fix that worked ([firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982), reproduced in the original runbook kept locally under `dev/archive/`): build GDAL 3.13 from source in the Rtools45 UCRT64 shell with `GDAL_USE_MUPARSER=ON`, point `gdalraster` compilation at it via Makevars, and make the DLLs resolvable at runtime via PATH + preload in `.Rprofile`.

That manual setup (`C:/gdal-ucrt64` + `C:/rtools45/ucrt64/bin` on PATH) is the ancestor of everything in this repo. Understanding *why it worked so reliably* took until July: all of its dependency DLLs came from one internally coherent, curated package set (Rtools45's ucrt64 tree). The productized bundle kept breaking precisely where it departed from that property.

## act 2: why the design looks the way it does

Each design element is a response to a constraint. In order:

**Why build GDAL with MinGW at all, instead of using an existing GDAL?** R packages on Windows are compiled by Rtools, which is MinGW-GCC targeting UCRT. `gdalraster` binds GDAL's C++ classes (not a C shim), and C++ has no standard ABI: MSVC and GCC differ in name mangling, exception handling, class layout, and STL types. An MSVC GDAL (conda-forge/pixi, OSGeo4W, vcpkg) is not linkable from Rtools-compiled code — the symbols don't even have the same names. So the GDAL must be MinGW-built. (Deep dive §4.)

**Why build in CI with MSYS2 rather than require users to build locally?** The manual runbook takes an hour and a toolchain install. CI builds once, publishes a versioned artifact, and every machine consumes the same bytes. The cost: MSYS2 is a rolling release, so the build environment's package set changes under us between builds — the root of two of the three production incidents (below).

**Why ship a "bundle" (DLL closure) instead of just `libgdal-*.dll`?** The import table of `libgdal-39.dll` names ~78 direct dependency DLLs, with hundreds transitive. On the build machine they live in `/ucrt64/bin`; user machines don't have that. `tools/collect_dlls.sh` walks the import tree (`ntldd -R`) and copies everything non-Windows into `bundle/bin`, then fails the build if anything remains unresolved. (Deep dive §2, §8.)

**Why rebuild `gdalraster` from source on the user's machine?** Same C++ ABI logic one level up: `gdalraster.dll` must be compiled against the bundle's GDAL headers and linked to its import library. The CRAN binary is linked (statically) against Rtools' own GDAL — different GDAL, no Algorithm API. `install_gdalraster()` does the source build with scoped Makevars (`withr::with_makevars`), so nothing persists in user config.

**Why does the package manage `PATH`/preload at session start?** Compile-time linking and run-time loading are separate systems. At `library(gdalraster)`, the Windows loader must resolve `libgdal-39.dll` and its entire closure *at that moment*, by base name, through the DLL search order. `activate_gdal_runtime()` prepends the bundle's `bin/` to `PATH`, sets GDAL/PROJ data variables, and preloads `libgdal` into the process so every later request reuses it (first-loaded-wins rule). (Deep dive §2.)

**Why is everything non-destructive/isolated by default?** The runtime installs under `tools::R_user_dir()` paths and `gdalraster` goes to an isolated library, because the target machines often *also* have the manual `C:/gdal-ucrt64` stack, CRAN sf/terra (which embed their own static GDAL), and unrelated GDALs (pixi/conda). Base-name collisions between GDAL stacks in one process are resolved by load order, so the package never wants to win by overwriting — only by activating first in sessions that opt in.

## act 3: the three production incidents

Every incident was a *distribution* failure, not a build failure — the DLL compiled and linked fine each time. This is the pattern to internalize: on Windows, the hard part is not producing a binary, it is controlling the environment the binary meets.

| # | Incident | Mechanism | Countermeasure now in place |
|---|---|---|---|
| 1 | `msodbcsql17.dll` (June, #13) | GDAL's cmake auto-detected the SQL Server ODBC SDK on the GitHub runner and linked it; bundle verification blanket-trusted System32, where that DLL exists on runners but not user machines | `GDAL_USE_MSSQL_ODBC/NCLI=OFF`; verifier denies known vendor DLLs in System32 |
| 2 | Missing-module failures during early adoption | Transitive DLLs absent from `PATH` at load time in sessions without activation | loud preload failure in `activate_gdal_runtime()`; troubleshooting flow |
| 3 | `ERROR_DLL_INIT_FAILED` 1114 (July, e2e) | MSYS2's `libpodofo.dll` runs OpenSSL setup in its static initializers (DllMain, under loader lock) and fails against MSYS2's `libcrypto` — in every process; `libgdal` imported podofo because MSYS2's gdal package pulls it in and cmake auto-detected it | PDF driver disabled outright (`GDAL_ENABLE_DRIVER_PDF=OFF` + all backends); banned-DLL guard in `collect_dlls.sh`; LoadLibrary smoke gate in `build.yml` |

Incident 3 deserves its own moral because it defeated the existing verification: the bundle was *complete* (every import resolved — `ntldd` proved it) but not *loadable* (one DLL failed initialization). Static inspection of any kind cannot catch that class; only actually loading the DLLs can. Hence the three-layer gate that now guards every release:

1. **closure** — `ntldd` walk + banned-DLL regex (`collect_dlls.sh`)
2. **loadability** — `LoadLibrary` over every bundled DLL in a plain process (`build.yml` step 7b), before anything is published
3. **functionality** — the e2e workflow runs the full documented user flow on a clean Windows runner whenever a bundle release is published

A secondary moral: incident 3 was initially misdiagnosed (blamed on an HDF5→OpenBLAS→Fortran conflict with R's own DLLs) and the wrong fix was merged before empirical bisection found podofo. Ten minutes of `LoadLibrary` sweeps beat hours of dependency-graph theory. When a DLL question arises, load things and observe.

## act 4: what "working" means today

The system is working when all of these hold:

- `build.yml` produces a bundle that passes closure + loadability gates and publishes it as a `gdal-v*` release asset
- `install_gdal_runtime()` + `install_gdalraster()` + `verify_gdalraster_runtime()` succeed on a clean machine (proven weekly and per-release by `e2e.yml`)
- `gdalraster::gdal_global_reg_names()` returns a non-empty registry, and the embedded-python path (`gdal driver gpkg validate`) can import `osgeo_utils`

The moving parts most likely to break it again, in likelihood order:

1. **MSYS2 package churn** — a dependency's new build fails DllMain or changes behavior (incident 3's class). Caught by the loadability gate.
2. **GDAL cmake auto-detection drift** — a new optional dependency appears in the build env and gets linked (incident 1's class). Caught partially by the banned-DLL guard; watch the "disabled features" cmake summary on version bumps.
3. **GDAL soname bump** (`libgdal-40.dll` for 3.14) — everything discovers the DLL by glob, but rebuilt `gdalraster` is required per bundle.
4. **Rtools GCC major-version jumps** — GCC's C++ ABI is backward-compatible in practice, and the bundle statically embeds its own libstdc++, but a jump is the right time to rerun e2e before trusting local results.

## reading map

| You want | Read |
|---|---|
| Use the package | `vignettes/getting-started.qmd` → `runtime-guide.qmd` (canonical, on pkgdown) |
| Fix a broken session | `vignettes/troubleshooting.qmd`, then `05-troubleshooting.md` |
| Understand the design | this file, then `vignettes/architecture.qmd` |
| Understand Windows DLL/ABI mechanics | [`08-windows-dll-abi-deep-dive.md`](08-windows-dll-abi-deep-dive.md) |
| Change the build/CI | `03-ci-and-release.md`, comments in `tools/build_gdal.sh` and `.github/workflows/build.yml` (the comments are the authoritative rationale) |
| Historical archaeology | `07-*`, `dev/archive/` (session-specific; never treat as current) |