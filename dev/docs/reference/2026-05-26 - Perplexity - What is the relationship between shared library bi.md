<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# What is the relationship between shared library binaries and executable binaries or runtimes that use them? For example, when I compile, build, install etc some static binary such as GDAL, what is the best way to understand concepts such as bundling dependencies (ie external shared libraries) statically into the resulting build vs doing something that implies those external dependencies will be available at runtime instead etc.? I recently made https://github.com/jimbrig/gdalraster.windows which is a custom R package and GDAL build that specifically uses the same MinGW based RTools45/MSYS2/UCRT (I also do not know what these are really, all I know is mingw is the open/unix based alternative to MSVC for windows but I do not know how MSYS2 and UCRT are related to mingw or what they are other than Unix environments for windows with bash shells) to compile a GDAL library that provides C++ ABI compatibility for the algorithmic api bindings from gdalraster. However I in turn also must rebuild gdalraster linking to this new gdal build and also ensure the DLL is loaded before librarying gdalraster also….

This is a rich and deeply interconnected question — let me break it down layer by layer.

***

## Binaries, Libraries, and Linking: The Foundation

At the most fundamental level, a **binary** is just compiled machine code in a file. The key distinction is whether a binary is *self-sufficient* or *dependent*:

- An **executable binary** (`.exe` on Windows, ELF with `main()` on Linux) has an entry point and can be launched by the OS directly.
- A **shared library** (`.dll` on Windows, `.so` on Linux) has no `main()`, exists purely to export functions/data, and is loaded into another process's address space either at startup or on demand.[^1_1]

The critical technical detail is that shared libraries use **position-independent code (PIC)** — their machine code is compiled so it can be mapped to *any* virtual memory address in a process, rather than being fixed. This is what lets multiple processes share the same library simultaneously.[^1_2]

***

## Static vs Dynamic Linking

When you compile and link a program (or a shared library like `gdal.dll`), you must decide how each of its *own* dependencies gets bundled:

**Static linking** copies the full object code of each dependency directly into your output binary at link time. The result is a single, self-contained artifact. No external `.dll` or `.so` needs to be present at runtime. The tradeoffs:[^1_3]

- Larger binary size (every consumer carries its own copy of each library)
- Easier deployment — it "just works" with no external deps to resolve
- Bug fixes in a dependency require a full recompile and redistribution of your binary[^1_3]
- Slight performance edge because symbol resolution happens at link time, not runtime[^1_3]

**Dynamic linking** records only a *reference* to a shared library in the binary's import table. The OS **loader** resolves and maps those dependencies at process startup (load-time dynamic linking) or when your code explicitly calls `LoadLibrary()` (runtime dynamic linking). The tradeoffs:[^1_4]

- Smaller binaries, shared memory footprint
- Dependencies *must* be present on the target machine at the correct path and version
- You can patch a buggy dependency by just replacing the `.dll` without rebuilding consumers[^1_3]

For your GDAL build, the key insight is: when you compile GDAL itself, it *dynamically links* many of its own dependencies (PROJ, GEOS, libcurl, SQLite, etc.) unless you explicitly tell the build system to link them statically with flags like `-static` or CMake options like `-DGDAL_USE_EXTERNAL_LIBS=...`. This means your `gdal.dll` will in turn require *those* DLLs at runtime.

***

## The C++ ABI Problem — Why You Had to Rebuild Everything

This is the crux of your `gdalraster.windows` project. **ABI** (Application Binary Interface) is the low-level contract between compiled binaries: how function names are mangled, how arguments are passed on the stack, how exceptions propagate, how vtables are laid out, etc.[^1_5]

The problem is that **C++ has no standardized ABI across compilers** — MSVC and MinGW/GCC use fundamentally different C++ ABIs. This means:[^1_6]

- If `gdal.dll` exposes C++ types (STL containers, virtual classes) and is compiled with MSVC, code compiled with MinGW GCC *cannot safely call those APIs*, even if the header files look identical[^1_7]
- The crash wouldn't necessarily be immediate — it could be a silent memory corruption, a misaligned vtable dispatch, or a thrown exception that crosses the ABI boundary and is never caught[^1_6]
- The *only* safe cross-compiler boundary for DLLs is **`extern "C"` linkage**, which disables name mangling and uses the C calling convention — but `gdalraster`'s bindings use the full C++ GDAL API, so that escape hatch doesn't apply here

This is precisely why you had to build your own GDAL using the same toolchain (RTools45/MinGW/UCRT64) that R itself uses on Windows — so the C++ ABI on both sides of the boundary is identical.

***

## The MSYS2 / MinGW / UCRT Ecosystem Demystified

These are four distinct but layered concepts:


| Term | What it actually is |
| :-- | :-- |
| **MinGW-w64** | A project that ports GCC (the GNU Compiler Collection) to Windows, targeting the native Win32 API. It produces `.exe`/`.dll` files that run natively without any Unix emulation layer [^1_8] |
| **MSYS2** | A *distribution* and *package manager* (using `pacman`) for Windows that bundles MinGW-w64 toolchains, plus a POSIX shell layer (bash, coreutils, make). It's the *environment* you work in, not the compiler itself [^1_9] |
| **MSVCRT** | The old Microsoft Visual C++ Runtime — the C standard library that ships on all Windows versions. The `MINGW64` MSYS2 environment links against this. It has known non-C99 issues and doesn't support UTF-8 locale [^1_9] |
| **UCRT** | Universal C Runtime — the modern replacement that Microsoft also uses in Visual Studio by default since VS2015. The `UCRT64` MSYS2 environment links against this, giving much better MSVC compatibility [^1_9] |

The critical rule: **you cannot safely mix binaries linked to MSVCRT with binaries linked to UCRT** at the object/static library level. For DLLs specifically, mixing is possible *as long as you don't share C runtime objects like `FILE*` or heap allocations across the boundary*. RTools45 specifically moved to UCRT64, which is why MSYS2's UCRT64 environment is the right toolchain to match.[^1_9]

As of 2026-03-15, **MSYS2 has actually deprecated the MINGW64 environment** in favor of UCRT64, validating the choice your project made.[^1_9]

***

## DLL Load Order and the `dyn.load()` Problem

Your observation that you must `dyn.load()` the GDAL DLL *before* calling `library(gdalraster)` directly reflects how Windows resolves DLL dependencies at load time. When Windows loads `gdalraster.dll`, it immediately needs to resolve all of *its* import table entries — including `gdal.dll` — via the DLL search order:[^1_10]

1. The directory of the loading executable (R's bin directory)
2. `System32`
3. The `PATH` environment variable entries, in order

If your custom `gdal.dll` isn't in any of those places, the load fails before any R code even runs. By calling `dyn.load("path/to/gdal.dll")` first, you get Windows to map that DLL into the process, after which it's in the **loaded-module list** (step 4 in the search order). When `gdalraster.dll` then loads and asks for `gdal.dll`, Windows finds it already resident in memory and uses it.[^1_10]

A more robust long-term approach is to use `Sys.setenv(PATH = ...)` to prepend your custom GDAL DLL's directory to `PATH` *before* the package loads, or to use `addDllDirectory()` (exposed via R's `.Machine$addDllDirectory`) on newer Windows/R builds. This way the system finds it automatically during the normal search rather than requiring manual pre-loading.

***

## How This All Ties Together for Your Build

Your `gdalraster.windows` workflow hits every one of these concepts in sequence:

1. You compile `gdal.dll` with UCRT64 GCC, which statically bundles some dependencies (like PROJ internals) or dynamically links others — this determines which additional DLLs need to travel with `gdal.dll`
2. You compile `gdalraster.dll` linking against your `gdal.dll`'s import library (`.dll.a`), using the same UCRT64 GCC — C++ ABI is now consistent across both[^1_5]
3. At R runtime, you pre-load `gdal.dll` into the process before `library(gdalraster)`, so the Windows loader finds it in the already-loaded-module list rather than searching PATH[^1_10]

The deeper architectural lesson is that **shared library systems are essentially a deferred promise** — when you build, you're writing an IOU ("I will need `gdal.dll` at runtime"), and the OS loader is the collections agency that either satisfies that IOU from what's available, or crashes your process if it can't. Static linking converts those IOUs into cash upfront at build time, eliminating the runtime collection problem entirely — at the cost of a larger, less updatable binary.[^1_3]
<span style="display:none">[^1_11][^1_12][^1_13][^1_14][^1_15][^1_16][^1_17][^1_18][^1_19][^1_20][^1_21][^1_22][^1_23][^1_24][^1_25][^1_26][^1_27][^1_28]</span>

<div align="center">⁂</div>

[^1_1]: https://en.wikipedia.org/wiki/Shared_library

[^1_2]: https://stackoverflow.com/questions/62415074/difference-between-shared-library-so-a-linux-executable-file-without-extensio

[^1_3]: https://www.sandordargo.com/blog/2024/10/02/dynamic-vs-static-linking

[^1_4]: https://stackoverflow.com/questions/11224123/load-time-dynamic-linking-import-library-search-order

[^1_5]: https://caiorss.github.io/C-Cpp-Notes/DLL-Binary-Components-SharedLibraries.html

[^1_6]: https://github.com/llvm/llvm-project/issues/60847

[^1_7]: https://github.com/caiorss/C-Cpp-Notes/blob/master/DLL-Binary-Components-SharedLibraries.org

[^1_8]: https://gitforwindows.org/the-difference-between-mingw-and-msys2.html

[^1_9]: https://www.msys2.org/docs/environments/

[^1_10]: https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order

[^1_11]: https://www.reddit.com/r/linux4noobs/comments/pybvdv/difference_between_binaries_and_libraries/

[^1_12]: https://forums.raspberrypi.com/viewtopic.php?t=204543

[^1_13]: https://www.jsoftware.com/help/user/dll_so.htm

[^1_14]: https://pypi.org/project/GDAL/

[^1_15]: https://news.ycombinator.com/item?id=32531224

[^1_16]: https://stackoverflow.com/questions/1993390/static-linking-vs-dynamic-linking

[^1_17]: https://stackoverflow.com/questions/76552264/what-are-msys2-environments-how-do-i-pick-one

[^1_18]: https://github.com/databrickslabs/mosaic/issues/524

[^1_19]: https://forum.dlang.org/thread/dobouzmhwabquswguunk@forum.dlang.org

[^1_20]: https://devinsights.iblogger.org/msys2-environment-differences/

[^1_21]: https://www.reddit.com/r/C_Programming/comments/1lw83ye/how_to_install_64bit_msys2_really/

[^1_22]: https://github.com/msys2/MSYS2-packages/discussions/4706

[^1_23]: https://stackoverflow.com/questions/15082060/set-up-a-msvc-dll-to-be-abi-compatible-to-a-stdcall-mingw-dll

[^1_24]: https://ziggit.dev/t/windows-gnu-mingw-and-msvc-binary-c-abi-compatibility-guarantees/6903

[^1_25]: https://forum.crystal-lang.org/t/how-to-detect-the-current-msys2-environment-ucrt64-mingw64-clang64-on-windows/8090

[^1_26]: https://github.com/dotnet/sdk/issues/33845

[^1_27]: https://github.com/microsoft/vscode-cpptools/issues/11063

[^1_28]: https://www.akshayjain.blog/post/understanding-the-windows-dll-search-order-a-deep-dive-into-internals-and-security-implications


---

# See https://github.com/firelab/gdalraster/issues/982 for my own explanation of what I did on my local machine and the response back.

Then actually review the package source code and particularly the GitHub action workflow that builds the GDAL binary: https://github.com/jimbrig/gdalraster.windows

And provide me with thorough insights back.

Now I have a very complete picture of the code, the issue thread, the upstream maintainer's response, and the full build/runtime architecture. Let me write the analysis.

***

## What You Built and Why It Works

Your package and workflow represent a genuinely sophisticated solution to a deep, multi-layered Windows C++ toolchain problem. Let me walk through every layer of what your code does, where it's clever, and where there are rough edges worth addressing.

***

## The Root Cause: Static Algorithm Registration in MXE Builds

The upstream problem in [issue \#826](https://github.com/firelab/gdalraster/issues/826) is subtle and worth understanding precisely . GDAL's Algorithm API uses **static C++ constructors** to self-register algorithms into a global registry at DLL load time — essentially, each algorithm's `.cpp` file contains a file-scope object whose constructor calls `GDALAlgorithmRegistry::Register()`. This works fine when GDAL is built as a shared library in a normal GCC/UCRT64 environment .

However, RTools45 uses a build system called **MXE** (M Cross Environment) which builds GDAL — and many of its deps — as **static archives (`.a` files)** that then get linked into a final shared `libgdal.dll` . The problem: when the linker pulls in object files from static archives, it uses **dead-code elimination** and only links objects that are explicitly referenced by something already in the link graph. Static initializers that *only* side-effect a global registry, and are never called by name from any other object, get silently discarded by the linker as unreachable dead code. The result is `gdal_global_reg_names()` returning `character(0)` — the registry is empty because the self-registration constructors never ran .

The fix confirmed by `ctoney` is that this was patched upstream in GDAL 3.12.2 via [GDAL PR \#13592](https://github.com/OSGeo/gdal/pull/13592), and separately, **muparser** was missing from RTools' GDAL build (it was added in RTools release 6768) . You independently arrived at the same two root causes: wrong GDAL version + missing muparser .

***

## The `build_gdal.sh` Script: What It Does and Why

Your [`tools/build_gdal.sh`](https://github.com/jimbrig/gdalraster.windows/blob/main/tools/build_gdal.sh) is the core artifact . The key CMake flags and the reasoning behind each:


| Flag | Why it's there |
| :-- | :-- |
| `-DGDAL_USE_MUPARSER=ON` | Enables the Algorithmic API — this is the primary fix |
| `-DGDAL_HIDE_INTERNAL_SYMBOLS=ON` | Reduces the DLL export table size; required because you hit `export ordinal too large 154394` errors — PE/COFF DLLs have a hard limit of 65535 export ordinals and GDAL's symbol count exceeds it without this |
| `-Wl,--kill-at` | MinGW adds an `@N` byte-count suffix to `__stdcall` symbol names (e.g. `Foo@8`). `--kill-at` strips these, producing clean symbol names that match MSVC-style import expectations — required for interop |
| `-static-libgcc -static-libstdc++ -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,-Bdynamic,--no-whole-archive` | **This is the single most important decision for distribution.** It embeds the GCC C++ and threading runtimes directly into the DLL rather than depending on `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll` being present |
| `-DBUILD_TESTING=OFF -DBUILD_APPS=OFF` | ~30% build time reduction with no impact on the runtime DLL |

The `--whole-archive` / `--no-whole-archive` sandwich around `-lwinpthread` is a non-obvious but critical linker trick. Normally `-Bstatic` prevents dead-code elimination, but `--whole-archive` forces *every* object in the archive to be included — necessary for pthreads because some initialization routines might otherwise be dropped .

***

## `collect_dlls.sh`: The Real Complexity

The [`tools/collect_dlls.sh`](https://github.com/jimbrig/gdalraster.windows/blob/main/tools/collect_dlls.sh) script is where the packaging actually becomes a hard problem . The approach uses `ntldd -R` — a recursive PE import tree walker for Windows — to walk every transitive dependency of `libgdal-39.dll` and collect any DLL that resolves to `/ucrt64/` (i.e., an MSYS2 package that won't exist on a plain Windows machine) .

The final verification step is the most important part of this script: it re-runs `ntldd` after bundling and asserts that **no remaining deps resolve outside of `C:/Windows/`**, failing the CI build with a nonzero exit code if anything slips through . This is a strong correctness guarantee — you can't accidentally ship a bundle that requires Rtools or MSYS2 to be installed.

One subtle issue in the safety-net: the script also explicitly copies `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll` as a fallback even though `build_gdal.sh` statically links those runtimes . This is defensive and harmless — the DLL already has the runtime embedded, so the copies in `bin/` would only be used by *other* DLLs in the bundle that weren't built with static runtime flags. Good defensive practice.

***

## The GitHub Actions Workflow Architecture

The `build.yml` workflow has a notably well-thought-out structure :

**Cache strategy**: The build cache is keyed on `gdal_version + runner.os + hash(build_gdal.sh, collect_dlls.sh)`. This means changing a version string or modifying either script invalidates the cache and forces a rebuild, but re-running the workflow to iterate on the R package side skips the 40-minute CMake build entirely . The cache key including the *script hash* (not just version) is sophisticated — most people only key on the version.

**`path-type: minimal`** in the MSYS2 setup step is critical and often overlooked . Without it, the Windows `PATH` (including any installed Rtools) bleeds into the MSYS2 shell environment. This can silently cause cmake's `find_package()` to pick up the *wrong* version of PROJ, GEOS, or other deps — from Rtools rather than UCRT64 — producing a DLL that links against Rtools' libraries instead of MSYS2's, which then fails at runtime when those paths don't exist. The comment in your workflow explicitly documents this risk .

**The two-job split** is also architecturally correct: Job 1 (`build-gdal`) runs entirely in MSYS2, produces a self-contained bundle, and passes it to Job 2 via `upload-artifact`. Job 2 (`verify-gdalraster-build`) uses `r-lib/actions/setup-r` which installs *Rtools45* (not MSYS2) — this correctly simulates an end-user R environment and proves the bundle works without MSYS2 present .

The smoke test in step 8 of Job 2 is exactly right:

```r
stopifnot(length(algs) > 0)
```

This directly tests the thing that was broken in issue \#826 — it won't pass with an empty registry .

***

## The R Package Layer

The R package (`gdalraster.windows`) serves as a bootstrap orchestrator. Its design is layered cleanly :

- `install_gdal_runtime()` — downloads the prebuilt bundle from a GitHub Release asset and unpacks it to a user-managed directory (resolved via `tools::R_user_dir()` by default)
- `activate_gdal_runtime()` — prepends `bin/` to `PATH`, sets `GDAL_DATA` and `PROJ_LIB`/`PROJ_DATA`, and calls `dyn.load(dll_path, local = FALSE, now = TRUE)`
- `install_gdalraster()` — uses `withr::with_makevars()` to set `PKG_CPPFLAGS`/`PKG_LIBS` scoped to a single `install.packages()` call, installing gdalraster from source into a dedicated `lib`
- `load_gdalraster()` — prepends the custom `lib` to `.libPaths()` before calling `library(gdalraster)`

The `zzz.R` `.onLoad` hook calls `startup_bootstrap()` automatically when `auto_bootstrap` option is TRUE , which means simply `library(gdalraster.windows)` will attempt the full setup sequence — a nice UX touch. The `startup_hook.R` utility `add_gdal_rprofile_hook()` writes a **managed marker block** (`# >>> gdalraster.windows hook >>>` / `# <<< gdalraster.windows hook <<<`) that can be idempotently re-written without duplicating the hook  — better than most R packages that just blindly append to `.Rprofile`.

The `install_gdalraster()` function uses `withr::with_makevars()` with `assignment = "="` rather than `"+="` . This is intentional: it *replaces* the `PKG_LIBS` variable rather than appending to any existing value. If a user already has a `~/.R/Makevars.win` pointing at a different GDAL, the `withr` scope overrides it for this install only without permanently modifying their file.

***

## Areas Worth Improving

**1. Hardcoded DLL version in `build_gdal.sh`**

The final `ls -lh "${INSTALL_DIR}/bin/libgdal-39.dll"` hardcodes the SONAME version `39` . When GDAL bumps its SONAME (as it does with major releases), this will produce a misleading "file not found" error without failing the build itself. Better: use a glob `libgdal-*.dll` like the rest of your scripts do.

**2. The `--allow-multiple-definition` linker flag in `install_gdalraster()`**

In `gdal_runtime.R`, the `PKG_LIBS` passed to the source install includes `-Wl,--allow-multiple-definition` . This flag silences linker errors that occur when the same symbol appears in multiple translation units — a genuine red flag. It can mask real ABI violations or symbol conflicts between the custom GDAL and residual Rtools GDAL symbols. It's understandable as a pragmatic fix for intermittent link failures, but ideally you'd identify and eliminate the duplicate symbols rather than suppressing the diagnostic.

**3. `GDAL_USE_ARROW=ON` without verifying Arrow IPC support**

The build enables both Arrow and Parquet , which requires libarrow and libparquet to be either statically linked or bundled. The `collect_dlls.sh` *should* pick these up via `ntldd`, but Arrow's DLL dependency tree is particularly deep (it pulls in Thrift, Boost, etc.). The CI verification only checks that `gdal_global_reg_names()` returns non-empty — it doesn't test Arrow-specific drivers. A smoke test like `gdalraster::vsi_list("/vsiarrow/...")` or checking `gdal_formats()` for `Arrow` would give higher confidence.

**4. No `inst/extdata/` fallback bundle**

The `install_gdal_runtime()` function references a `packaged_fallback_zip()` that points to `inst/extdata/gdal-ucrt64-fallback.zip` . But looking at the package structure, no such zip is actually bundled in the repository  — the `inst/` directory likely doesn't contain it due to its size. The fallback path is defensive, but documenting clearly in the package that the fallback is only available after a manual local build (not from CRAN/GitHub install) would prevent confusion.

**5. The upstream fix makes your solution partly obsolete (but not fully)**

`ctoney`'s response confirms that the static registration bug was fixed upstream in GDAL 3.12.2 and will be part of the next RTools update targeting GDAL 3.13.1 . Once that RTools release lands, the default `gdalraster` install from CRAN will "just work" for the Algorithm API. However, your package still provides genuine value beyond the bug fix: it pins a specific GDAL version, enables Arrow/Parquet/HDF5/NetCDF drivers that the lean MXE build may omit, and provides a reproducible CI pipeline for anyone who needs a custom GDAL feature set on Windows.

***

## Summary of the Build Pipeline Flow

```
git tag gdal-v3.13.0
        │
        ▼
Job 1 (MSYS2 UCRT64 shell)
  ├── install UCRT64 toolchain + deps (muparser, arrow, hdf5, ...)
  ├── cmake configure (--kill-at, -static-libgcc, MUPARSER=ON, HIDE_SYMBOLS=ON)
  ├── cmake build → libgdal-39.dll
  ├── collect_dlls.sh: ntldd -R → copy /ucrt64 deps → verify self-contained
  └── upload artifact + GitHub Release zip
        │
        ▼
Job 2 (Rtools45 / standard Windows R env)
  ├── download GDAL bundle from Job 1
  ├── write ~/.R/Makevars.win pointing at bundle
  ├── download gdalraster source from CRAN
  ├── R CMD INSTALL --build --no-test-load (links against bundled GDAL)
  ├── smoke test: gdal_global_reg_names() returns length > 0 ✓
  └── upload gdalraster binary artifact
```

The end-to-end result is a fully self-contained `libgdal-39.dll` that carries its own runtime, a `gdalraster.dll` linked against it with matching C++ ABI, and an R package that orchestrates installation, PATH management, DLL preloading, and `.Rprofile` persistence — all without requiring the end user to have MSYS2, Rtools, or any compiler toolchain installed.

---

# Another potential aspect of this I just thought about due to me having to deal with similar problems for my Linux WSL distro environment where I link and build against a pixi managed GDAL 3.13 when installing gdalraster to get the latest version and enable arrow / parquet driver support etc. is the ability to additionally have sf and terra package installations and result in alternative package builds against this new GDAL build - can you explore the feasibility of that for this windows implementation and any nuances involved? I know that sf does not use rtools45 binaries I don’t think and on linux it would install its own legacy (3.8) GDAL as a sysreq etc. which in worked around successfully from Linux but not sure about windows.

I now have a very complete picture. Let me write the comprehensive analysis.

***

## sf and terra Against a Custom GDAL on Windows: Feasibility and Nuances

This is deeply feasible but requires navigating several interlocking problems that are quite different from the Linux/pixi case. Here's a thorough breakdown.

***

## How sf and terra Actually Link on Windows

The first critical thing to understand is what `Makevars.ucrt` does for both packages — and this is the key insight that changes everything. Both `sf` and `terra` have essentially **identical** `Makevars.ucrt` files :

```makefile
ifeq (,$(shell pkg-config --version 2>/dev/null))
  PKG_LIBS = -lgdal -larmadillo -lopenblas ... [~50 static Rtools libs] ... -lproj -lsqlite3 ...
else
  PKG_LIBS = $(shell pkg-config --libs gdal geos proj)
endif

winlibs:
	cp -r "$(R_TOOLS_SOFT)/share/gdal" ../inst/
	cp -r "$(R_TOOLS_SOFT)/share/proj" ../inst/
```

The `ifeq` branch checks whether `pkg-config` is available. In a stock Rtools45 environment, **`pkg-config` is not on `PATH`** (or is present but not configured to find the UCRT64 packages) so the `ifeq` branch fires, hardcoding a massive explicit list of static libraries from `$(R_TOOLS_SOFT)` — the Rtools UCRT64 sysroot . The `winlibs:` target then **copies GDAL and PROJ data files from Rtools into `inst/`** inside the built package — this is why `sf` and `terra` are fully self-contained on Windows .

The implication: **if `pkg-config` is available and configured** — as it would be in an MSYS2 shell pointing at your UCRT64 GDAL bundle — the second branch fires and `pkg-config --libs gdal geos proj` will emit your custom GDAL's paths. This is the clean mechanism both packages already provide for custom builds.

***

## The DLL Conflict Problem: The Core Danger

When you have a custom GDAL build (`libgdal-39.dll`) from `gdalraster.windows` and then also load `sf` or `terra` in the same R session — regardless of how they were compiled — you face the fundamental **Windows DLL deduplication rule**: `LoadLibrary` identifies DLLs by their *filename*, not their full path. The Windows loader keeps one canonical handle per DLL name per process. The second `LoadLibrary("libgdal-39.dll")` simply returns a reference to the already-loaded module — it does not load a second independent copy.[^4_1][^4_2]

This means: **if `sf` or `terra` were compiled against Rtools' GDAL and your gdalraster was compiled against your custom GDAL bundle**, yet both DLLs happen to have the same filename `libgdal-39.dll` (same SONAME), only the first one loaded wins. The package loaded second will be calling functions in the wrong library. This is not a crash — it's a silent ABI mismatch that may appear to work for basic operations but will fail subtly or catastrophically on codepaths that use features compiled into one build but not the other (e.g., Arrow/muparser in your build vs. missing in Rtools' build).[^4_1]

The safe outcome only happens when **all three packages link against the exact same `libgdal-39.dll` binary** — your custom one.

***

## The Path to Actually Making This Work

There are two distinct strategies, each with different complexity trade-offs.

### Strategy 1: Recompile sf and terra Against Your Bundle (Full Solution)

This mirrors exactly what `install_gdalraster()` does in your package, extended to `sf` and `terra`. The approach would be:

**For sf:**

```r
withr::with_makevars(
  new = c(
    PKG_CPPFLAGS = paste0('-I"', file.path(gdal_home, "include"), '"'),
    PKG_LIBS     = paste0('-L"', file.path(gdal_home, "lib"), '" -lgdal -lgeos_c -lproj'),
    R_TOOLS_SOFT = gdal_home   # override so winlibs copies YOUR gdal/proj data
  ),
  assignment = "=",
  {
    withr::with_envvar(c(PATH = ..., GDAL_DATA = ..., PROJ_LIB = ...), {
      install.packages("sf", type = "source", lib = custom_lib,
                       INSTALL_opts = "--no-test-load")
    })
  }
)
```

However, there is a **critical complication** in `sf`'s `Makevars.ucrt` . The `winlibs:` target does `cp -r "$(R_TOOLS_SOFT)/share/gdal" ../inst/`. If you override `R_TOOLS_SOFT` to point at your bundle, `sf` will copy your bundle's `share/gdal` and `share/proj` into its `inst/` — which is exactly what you want, since `sf` will then ship its own GDAL/PROJ data pointing at your build's data files. But this also means the `PKG_LIBS` hardcoded list (50+ static libs!) becomes irrelevant in the `ifeq` branch only if `pkg-config` is found. Your best bet is to **ensure `pkg-config` is available and configured** so the `else` branch fires.

In your MSYS2 UCRT64 environment, this works automatically because `pkg-config --libs gdal` will correctly emit your build's flags. The problem is that the *source install* runs in the R process (not the MSYS2 shell), so `pkg-config` needs to be on `PATH` inside the `withr::with_envvar()` scope.

**For terra**, the situation is structurally identical to `sf` — same `Makevars.ucrt` pattern . The only additional dependency to worry about is TBB (`libtbb12` in the `pkg-config` branch). Your custom GDAL build wouldn't ship TBB, so you'd need it from UCRT64 and bundled alongside.

***

### Strategy 2: CRAN Binaries for sf/terra + Runtime PATH Ordering

The path of least resistance — and what many people do without realizing the risk — is loading the CRAN binary `sf` and `terra` alongside your custom-GDAL `gdalraster`. Whether this is *safe* depends on the GDAL SONAME version:

- **If Rtools' GDAL and your custom GDAL both produce `libgdal-39.dll`**: only one is loaded, determined by which package first calls `dyn.load()`. If you call `activate_gdal_runtime()` (which prepends your `bin/` to PATH and calls `dyn.load(dll_path, local=FALSE, now=TRUE)`) *before* `library(sf)`, your DLL wins and `sf` will use your custom GDAL at runtime. This is a legal but fragile arrangement — `sf` was compiled against Rtools' static libs list, but at runtime it resolves symbols from your DLL. As long as the ABI is compatible (same major GDAL, same calling conventions, MinGW toolchain on both sides), this usually works for the ~95% of operations that don't touch Arrow/muparser-specific codepaths.
- **If SONAME versions differ** (e.g., Rtools has `libgdal-38.dll`, you built `libgdal-39.dll`): both can coexist in memory because Windows treats them as different DLLs. `sf` binds to `libgdal-38.dll` from Rtools, `gdalraster` binds to your `libgdal-39.dll`. No conflict — they load fully independently. This is the cleanest accidental outcome, and worth checking on your specific Rtools vs. custom GDAL versions.

***

## The Linux Parallel and Why Windows Is Harder

On your WSL/pixi setup, you solved this by ensuring the pixi-managed `libgdal.so.X.Y.Z` was first on `LD_LIBRARY_PATH` before R started . Linux ELF shared libraries have versioned SONAME symbols and the dynamic linker uses `SONAME` + `rpath`/`runpath` embedded in each `.so` at build time, so two libraries with different SONAMEs load peacefully in the same process. On Linux, `sf` tries to install its own legacy GDAL (typically 3.8 from `libgdal-dev` on Ubuntu) as a sysreq — you worked around this by ensuring your pixi GDAL took precedence before configure ran .

On Windows, the problem is structurally worse: there are no `rpath`/`runpath` mechanisms. Windows DLL resolution is pure PATH + KnownDLLs + side-by-side assembly lookup order, with no way to embed a preferred search path into a DLL at link time (the `DT_RPATH` equivalent simply doesn't exist in PE/COFF format). The only lever you have is controlling `PATH` order before the first `LoadLibrary` call.[^4_1]

Additionally, `sf`'s `Makevars.ucrt` hardcodes static linkage against ~50 Rtools libraries without versions  — if those libraries have ABI-level differences from your UCRT64 bundle's versions (e.g., different PROJ patch version, different GEOS), you'd need your bundle to provide every one of those `.a` files at matching versions too. This is why a full source rebuild against your bundle is the only truly correct approach.

***

## Practical Recommendation for the Windows Package

An `install_sf()` and `install_terra()` function in `gdalraster.windows` is feasible and would follow the same pattern as `install_gdalraster()` . The key differences to account for:


| Concern | `gdalraster` | `sf` / `terra` |
| :-- | :-- | :-- |
| `Makevars.ucrt` branch | No `ifeq` — simple flags | `ifeq pkg-config` — need pkg-config available OR override `R_TOOLS_SOFT` |
| `winlibs:` data copy | No `inst/` data copying | Copies `share/gdal` + `share/proj` into `inst/` — need `R_TOOLS_SOFT` override |
| Additional deps | Only GDAL | sf also needs GEOS, PROJ; terra needs TBB |
| `-Wl,--allow-multiple-definition` | Already present in your code | Likely needed here too due to same symbol duplication pattern |
| GEOS/PROJ bundling | Your GDAL DLL embeds these or they're in your `bin/` | Need to verify they're present in your bundle's `lib/` as `.a` files |

The cleanest implementation would expose `pkg-config` from the bundle (MSYS2 UCRT64 provides `.pc` files in `lib/pkgconfig/`) and set `PKG_CONFIG_PATH` to point at them during the source install. This lets `sf`'s and `terra`'s `Makevars.ucrt` take the `pkg-config` branch naturally and emit correct link flags without you needing to maintain a hardcoded 50-library list .

One additional build flag to add for `sf`: `-DHAVE_PROJ_H` is currently hardcoded in `sf`'s `Makevars.ucrt`  but absent from the `else`/`pkg-config` branch, suggesting it's expected to be provided by `pkg-config`'s `--cflags`. Confirm your bundle's PROJ `.pc` file emits `-DHAVE_PROJ_H` in its `Cflags` output.

***

## Summary of the Risk Profile

- **Same GDAL SONAME, CRAN binaries, activation-first ordering** → *Probably works* for basic operations, fragile for Arrow/muparser features, depends on ABI compatibility. Low effort.
- **Same GDAL SONAME, all three compiled from source against your bundle** → *Correct and robust*, requires extending `gdalraster.windows` with `install_sf()` / `install_terra()` wrappers and bundling GEOS/PROJ static archives. Significant effort.
- **Different GDAL SONAMEs** → *Works accidentally and cleanly*, sf/terra use Rtools GDAL, gdalraster uses yours. No conflict, but no feature sharing across packages.

The most principled path — and the one that would make `gdalraster.windows` genuinely valuable beyond just fixing the Algorithm registry issue — is the source-rebuild approach with `pkg-config` delegation. You already have the architecture for it; it's a matter of extending the pattern you built for `gdalraster` to cover `sf` and `terra` with the additional nuance of their `R_TOOLS_SOFT`-rooted `winlibs:` data copy step.
<span style="display:none">[^4_10][^4_11][^4_12][^4_13][^4_14][^4_15][^4_16][^4_17][^4_18][^4_19][^4_20][^4_21][^4_22][^4_23][^4_24][^4_25][^4_26][^4_27][^4_28][^4_29][^4_3][^4_30][^4_31][^4_32][^4_33][^4_34][^4_35][^4_36][^4_37][^4_38][^4_39][^4_4][^4_40][^4_41][^4_5][^4_6][^4_7][^4_8][^4_9]</span>

<div align="center">⁂</div>

[^4_1]: https://stackoverflow.com/questions/38698293/can-i-get-separate-dlls-to-resolve-their-imported-dlls-separately

[^4_2]: https://stat.ethz.ch/R-manual/R-devel/library/base/help/dyn.load.html

[^4_3]: https://github.com/r-spatial/sf

[^4_4]: https://stackoverflow.com/questions/44973639/trouble-installing-sf-due-to-gdal

[^4_5]: https://cran.r-project.org/package=sf

[^4_6]: https://firelab.github.io/gdalraster/

[^4_7]: https://www.rdocumentation.org/packages/sf/versions/0.1-3

[^4_8]: https://github.com/rspatial/terra/issues/487

[^4_9]: https://www.hec.usace.army.mil/confluence/rasdocs/raski/latest/gdal-installation-issues

[^4_10]: https://community.databricks.com/t5/data-engineering/install-r-package-quot-sf-quot/td-p/60090

[^4_11]: https://stackoverflow.com/questions/74575722/most-recent-terra-package-for-r-will-not-compile

[^4_12]: https://stackoverflow.com/questions/6009506/unable-to-install-python-and-gdal-dll-load-failed

[^4_13]: https://r-spatial.r-universe.dev/sf

[^4_14]: https://github.com/rspatial/terra

[^4_15]: https://github.com/pyinstaller/pyinstaller/issues/1376

[^4_16]: https://github.com/r-spatial/sf/discussions/2502

[^4_17]: https://www.rdocumentation.org/packages/terra/versions/0.9-12

[^4_18]: https://github.com/r-spatial/sf/issues/2159

[^4_19]: https://cran.r-project.org/doc/manuals/r-release/R-exts.html

[^4_20]: https://github.com/r-spatial/sf/issues/408

[^4_21]: https://stackoverflow.com/questions/315285/can-i-use-two-incompatible-versions-of-the-same-dll-in-the-same-process

[^4_22]: https://github.com/cran/rgdal/blob/master/inst/README.windows

[^4_23]: https://www.reddit.com/r/gis/comments/1517den/trouble_with_installing_gdal/

[^4_24]: https://stackoverflow.com/questions/40634484/correct-installation-of-rtools-on-windows

[^4_25]: https://gdal.org/en/stable/development/building_from_source.html

[^4_26]: https://faims2-documentation.readthedocs.io/en/latest/Installing+GDAL+Tools+on+Windows/

[^4_27]: https://colinfay.me/writing-r-extensions/creating-r-packages-1.html

[^4_28]: https://gamedev.net/forums/topic/677890-dll-access-mechanism-between-multiple-applications/

[^4_29]: https://stackoverflow.com/questions/72386315/is-it-possible-for-a-process-to-load-two-dll-with-same-name-but-different-versio

[^4_30]: http://forum.vvvv.org/t/how-to-deal-with-different-versions-of-same-dll/14330

[^4_31]: https://learn.microsoft.com/en-us/answers/questions/5652481/how-to-use-multiple-dlls-with-the-same-name

[^4_32]: https://michaelscodingspot.com/dotnet-dll-hell/

[^4_33]: https://dev.to/johnnymakestuff/how-to-use-two-versions-of-the-same-dll-in-the-same-project-31db

[^4_34]: https://devnet.kentico.com/articles/referencing-multiple-versions-of-the-same-assembly-in-a-single-application

[^4_35]: https://www.reddit.com/r/csharp/comments/1h4qzte/is_a_dll_when_loaded_considered_as_another_process/

[^4_36]: http://mynameiskali.blogspot.com/p/c-20-using-different-versions-of-same_24.html

[^4_37]: https://rdrr.io/r/base/dynload.html

[^4_38]: https://forums.ni.com/t5/LabVIEW/Execute-multiple-versions-of-the-same-NET-DLL/td-p/4192116

[^4_39]: https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/dyn.load

[^4_40]: https://www.reddit.com/r/csharp/comments/10gvqki/why_are_there_different_versions_for_the_same_dll/

[^4_41]: https://learn.microsoft.com/en-us/windows/win32/dlls/about-dynamic-link-libraries


---

# Note that neither sf nor terra include low level bindings to C++ APIs like the algorithmic API in a manner like gdalraster does with user facing functions etc. - in other words, this idea is primarily for providing a more ideal state that doesn’t require separate isolated GDALs or the fact that gdalraster can write and interact with libarrow drivers but sf cannot etc. which is still definitely a good practice or idea. From the prior response it may also be worth considering applying a similar pattern for the custom gdalraster build with the pkg-config and copied self container DLL in the packages installed folder along side its gdalraster.DLL which could help me avoid the pre library dyn load requirement right?

Now I have a very complete picture of both the package architecture and the exact question being asked. The question is fundamentally about eliminating the pre-`library()` `dyn.load` requirement by shipping `libgdal-*.dll` **inside the `gdalraster` package's own directory** — the same pattern `sf` and `terra` already use — so the DLL is co-located with `gdalraster.dll` and gets found automatically at load time without any PATH manipulation.

***

## The Core Insight: Co-located DLLs vs. Runtime PATH Manipulation

Your current architecture requires a specific ordering: `activate_gdal_runtime()` (or the `.onLoad` auto-bootstrap) must run before `library(gdalraster)` so that `PATH` is prepended with the `bin/` directory and `libgdal-*.dll` is preloaded via `dyn.load()` before `gdalraster.dll` tries to find it . This is fragile — as the `.onAttach` warning in your own `zzz.R` explicitly acknowledges: *"gdalraster was already loaded before gdalraster.windows; restart session for full bootstrap control"* .

The alternative you're proposing is sound and is exactly what `sf` and `terra` already do: the `winlibs:` target in their `Makevars.ucrt` copies `share/gdal` and `share/proj` into `inst/` at build time , and the built package ships those data files inside its installed directory. The analogous move for `gdalraster` is to **copy `libgdal-*.dll` and all its bundled dependency DLLs directly into `gdalraster/libs/x64/`** (the directory where `gdalraster.dll` itself lives), which changes the DLL resolution story completely.

***

## Why This Works: Windows DLL Search Order

When the Windows loader resolves imports for `gdalraster.dll`, the search order is:[^5_1]

1. The directory containing the loading DLL itself (`gdalraster/libs/x64/`)
2. The process working directory
3. System directories (`C:\Windows\System32`, etc.)
4. Directories on `PATH`

Step 1 is the key: if `libgdal-39.dll` is sitting in the same directory as `gdalraster.dll`, Windows finds it there **without `PATH` needing to be set at all**, before it even checks `PATH`. This is the canonical Windows pattern for self-contained application DLL bundling and is why `sf` and `terra`'s approach of copying into `inst/` works — their compiled `.dll` files end up adjacent to the bundled DLLs after `R CMD INSTALL`.

For the `gdalraster` source install that `install_gdalraster()` performs, you already control the entire install pipeline via `withr::with_makevars()`. You can add a post-install step that copies the full set of DLLs from your `gdal_home/bin/` into the installed package's `libs/x64/` directory — precisely mirroring what `sf`'s `winlibs:` make target does at build time .

***

## Concrete Implementation

The change is a post-`install.packages()` copy step inside `install_gdalraster()`. After the source install completes, the installed `gdalraster` package directory will be at `file.path(lib, "gdalraster")`. Its DLL lives at `libs/x64/gdalraster.dll`. You need to copy all of `gdal_home/bin/*.dll` there:

```r
# After the existing install.packages() call in install_gdalraster():

gdalraster_libs_dir <- file.path(lib, "gdalraster", "libs", "x64")
if (!dir.exists(gdalraster_libs_dir)) {
  cli::cli_abort("gdalraster libs dir not found after install: {.path {gdalraster_libs_dir}}")
}

gdal_dlls <- list.files(gdal_bin_dir(gdal_home), pattern = "\\.dll$", full.names = TRUE)
n_copied <- 0L
for (dll in gdal_dlls) {
  dest <- file.path(gdalraster_libs_dir, basename(dll))
  if (!file.exists(dest)) {
    file.copy(dll, dest)
    n_copied <- n_copied + 1L
  }
}
cli::cli_alert_success(
  "copied {n_copied} GDAL runtime DLL{?s} into {.path {gdalraster_libs_dir}}"
)
```

With this in place, `library(gdalraster)` calls `dyn.load("gdalraster/libs/x64/gdalraster.dll")` and the Windows loader resolves `libgdal-39.dll` from the same directory — no `PATH` manipulation, no pre-load, no `.Rprofile` hook needed for the DLL resolution path.

***

## What This Means for `activate_gdal_runtime()` and `.onLoad`

Once the DLLs are co-located, the `activate_gdal_runtime()` call in `.onLoad` becomes responsible for only two things, not three:


| Responsibility | Co-located DLLs | Current approach |
| :-- | :-- | :-- |
| `libgdal-*.dll` is found at load time | ✅ Automatic via directory search | ❌ Requires pre-load / PATH prepend |
| `GDAL_DATA` env var set | Still needed | Still needed |
| `PROJ_LIB` / `PROJ_DATA` env vars set | Still needed | Still needed |
| `PATH` prepend for `gdal_translate` CLI tools | Still needed if user calls CLI | Still needed |

The `preload = TRUE` default in `activate_gdal_runtime()` and the `dyn.load()` call in `load_gdal_dll()` become **optional** rather than mandatory . You'd still want to set `GDAL_DATA` and `PROJ_LIB` in `.onLoad` so gdalraster can find projection data, but this can happen *after* `gdalraster.dll` is loaded — it doesn't need to precede it.

You could also copy `share/gdal` and `share/proj` into `gdalraster/inst/gdal` and `gdalraster/inst/proj` (analogous to `sf`'s `winlibs:` target) , then set the env vars from `system.file("gdal", package = "gdalraster")` in `.onLoad`. That makes the package fully self-contained — no dependency on `gdal_home` existing at runtime for data files, only for CLI tools.

***

## The pkg-config Angle

Your question also mentions making the build use `pkg-config` more naturally. This is complementary: shipping a `gdal.pc`, `geos.pc`, and `proj.pc` file inside `gdal_home/lib/pkgconfig/` (which your MSYS2 UCRT64 build already generates) and setting `PKG_CONFIG_PATH` in the `withr::with_envvar()` scope during `install_gdalraster()` means:

- `sf`'s and `terra`'s `Makevars.ucrt` would take the `pkg-config` branch naturally
- `gdalraster`'s own source install doesn't need the hardcoded `PKG_CPPFLAGS`/`PKG_LIBS` construction since `configure` can discover them
- The `-Wl,--allow-multiple-definition` flag could potentially be removed if the `pkg-config` flags produce a cleaner link without the symbol duplication that flag is currently suppressing

The clean `withr` scope for all three packages would become:

```r
withr::with_envvar(c(
  PATH            = paste(c(gdal_bin_dir(gdal_home), Sys.getenv("PATH")), collapse = ";"),
  PKG_CONFIG_PATH = file.path(gdal_home, "lib", "pkgconfig"),
  GDAL_DATA       = gdal_share_gdal_dir(gdal_home),
  PROJ_LIB        = gdal_share_proj_dir(gdal_home),
  PROJ_DATA       = gdal_share_proj_dir(gdal_home)
), {
  # pkg-config branch fires automatically for sf and terra
  install.packages("sf",    type = "source", lib = lib, INSTALL_opts = "--no-test-load")
  install.packages("terra", type = "source", lib = lib, INSTALL_opts = "--no-test-load")
  # gdalraster can also use pkg-config, dropping the manual Makevars construction
  install.packages(tarball,  type = "source", lib = lib, INSTALL_opts = "--no-test-load")
})
# Then copy DLLs into each package's libs/x64/
for (pkg in c("gdalraster", "sf", "terra")) {
  copy_gdal_dlls_to_pkg(gdal_home, lib, pkg)
}
```


***

## One Nuance: DLL Count and Package Size

Your `collect_dlls.sh` bundles every transitive UCRT64 dependency — Arrow, HDF5, NetCDF, PostgreSQL client, etc. . That DLL set is likely 80–120 files and probably 150–300 MB total. Copying all of them into each package's `libs/x64/` triples the disk footprint if you install all three packages. You have two options:

- **Shared `libs/x64/` symlinks** — not reliable on Windows without admin rights (symlinks require a privilege)
- **One canonical copy, one consumer** — keep the DLLs in `gdalraster/libs/x64/` only, and rely on the fact that once `libgdal-39.dll` is loaded into the process by `gdalraster`, `sf` and `terra` will resolve to the already-loaded module when they call `LoadLibrary("libgdal-39.dll")` — the exact Windows DLL deduplication behavior that was a liability before now becomes an asset[^5_1]

The load ordering requirement you were trying to eliminate is replaced by a package-load ordering that's much softer: `library(gdalraster)` must come before `library(sf)` and `library(terra)`, which is a natural dependency order any user would follow anyway. You can reinforce this with a simple check in `sf`'s/`terra`'s `.onLoad` path inside your bootstrap wrapper.

<div align="center">⁂</div>

[^5_1]: https://stackoverflow.com/questions/38698293/can-i-get-separate-dlls-to-resolve-their-imported-dlls-separately


---

# Review everything from this session and thorough online research to ground your context and reasoning in the reality of this realm and not the specifics of this specific implementation and in turn provide guidance pertaining to this latest question and initial response back regarding making the current gdalraster work more streamlined as well as the idea to bring in sf and terra as possible extensions to integrate with

Here's the report — it pulls everything together from the session context, the actual `Makevars.ucrt` source in `sf` and `terra`, the Windows DLL loader internals, and the upstream GDAL fix trajectory.

The core takeaways at a glance:

**On streamlining what you have:**

- The `-Wl,--allow-multiple-definition` flag in `install_gdalraster()` is the most important thing to fix — it's masking a real symbol conflict that should be traced to its root (almost certainly Rtools GDAL `.a` files bleeding into the link). Use `-Wl,--warn-duplicate-common` to identify the culprits first.
- Add an early warning when `sf` or `terra` are already loaded before `activate_gdal_runtime()` runs — the ordering guarantee is the entire mechanism by which CRAN-binary `sf`/`terra` can be coerced to use your GDAL.
- The hardcoded `libgdal-39.dll` version check in `build_gdal.sh` will silently break on next SONAME bump.

**On sf and terra extension:**

- Both `sf` and `terra` already have a clean `pkg-config` branch in their `Makevars.ucrt` — the hook is there, you just need `pkg-config` on `PATH` or `R_TOOLS_SOFT` overridden to point at your bundle so the `winlibs:` target copies your GDAL data into `inst/` rather than Rtools'.
- `terra` needs `libtbb12` in the bundle for full TBB parallelism — it's in UCRT64, just needs bundling.
- The fundamental DLL identity rule means activation-first ordering is non-negotiable, and for source-rebuilt packages it's a non-issue entirely.

**On the Linux comparison:** The reason pixi works cleanly on WSL is `RPATH`/`RUNPATH` — the Linux ELF loader can honor per-library preferred paths. PE/COFF has no equivalent, which is precisely why the `dyn.load(full_path, local=FALSE, now=TRUE)` before any `library(sf)` call is the only viable mechanism on Windows.
<span style="display:none">[^6_1][^6_10][^6_100][^6_101][^6_102][^6_103][^6_104][^6_105][^6_106][^6_107][^6_108][^6_109][^6_11][^6_110][^6_111][^6_112][^6_113][^6_114][^6_115][^6_116][^6_117][^6_118][^6_119][^6_12][^6_120][^6_121][^6_122][^6_123][^6_124][^6_125][^6_126][^6_127][^6_128][^6_129][^6_13][^6_130][^6_131][^6_132][^6_133][^6_134][^6_135][^6_136][^6_137][^6_138][^6_139][^6_14][^6_140][^6_141][^6_142][^6_143][^6_144][^6_145][^6_146][^6_147][^6_148][^6_149][^6_15][^6_150][^6_151][^6_152][^6_153][^6_154][^6_155][^6_156][^6_157][^6_158][^6_159][^6_16][^6_160][^6_161][^6_162][^6_163][^6_164][^6_165][^6_166][^6_167][^6_168][^6_169][^6_17][^6_170][^6_171][^6_172][^6_173][^6_174][^6_175][^6_176][^6_177][^6_18][^6_19][^6_2][^6_20][^6_21][^6_22][^6_23][^6_24][^6_25][^6_26][^6_27][^6_28][^6_29][^6_3][^6_30][^6_31][^6_32][^6_33][^6_34][^6_35][^6_36][^6_37][^6_38][^6_39][^6_4][^6_40][^6_41][^6_42][^6_43][^6_44][^6_45][^6_46][^6_47][^6_48][^6_49][^6_5][^6_50][^6_51][^6_52][^6_53][^6_54][^6_55][^6_56][^6_57][^6_58][^6_59][^6_6][^6_60][^6_61][^6_62][^6_63][^6_64][^6_65][^6_66][^6_67][^6_68][^6_69][^6_7][^6_70][^6_71][^6_72][^6_73][^6_74][^6_75][^6_76][^6_77][^6_78][^6_79][^6_8][^6_80][^6_81][^6_82][^6_83][^6_84][^6_85][^6_86][^6_87][^6_88][^6_89][^6_9][^6_90][^6_91][^6_92][^6_93][^6_94][^6_95][^6_96][^6_97][^6_98][^6_99]</span>

<div align="center">⁂</div>

[^6_1]: https://github.com/firelab/gdalraster/issues/858

[^6_2]: https://raw.githubusercontent.com/OSGeo/gdal/master/NEWS.md

[^6_3]: https://blog.aaronballman.com/2011/08/what-happens-when-you-load-a-library/

[^6_4]: https://www.cnblogs.com/shangdawei/p/4056967.html

[^6_5]: https://limbioliong.wordpress.com/2012/06/26/loading-2-dlls-of-the-same-name/

[^6_6]: https://stackoverflow.com/questions/38738899/multiple-loadlibrary-for-copies-of-the-same-dll

[^6_7]: https://www.akshayjain.blog/post/understanding-the-windows-dll-search-order-a-deep-dive-into-internals-and-security-implications

[^6_8]: https://r-spatial.github.io/sf/

[^6_9]: https://gdal.org/en/stable/download.html

[^6_10]: https://anaconda.org/conda-forge/r-gdalraster

[^6_11]: https://github.com/dlfcn-win32/dlfcn-win32/issues/104

[^6_12]: https://www.youtube.com/watch?v=-UQsUoMSlio

[^6_13]: https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order

[^6_14]: https://stackoverflow.com/questions/74700637/determining-which-r-packages-and-dependencies-use-dll-files

[^6_15]: https://forums.mydigitallife.net/threads/windows-internals-today-topic-ldrloaddll-loadlibraryexw.89432/

[^6_16]: https://cran.r-project.org/bin/windows/base/rw-FAQ.html

[^6_17]: https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-loadlibraryexw

[^6_18]: https://redcanary.com/threat-detection-report/techniques/dll-search-order-hijacking/

[^6_19]: https://stackoverflow.com/questions/42051228/workaround-bug-of-loadlibraryex-load-library-search-dll-load-dir-loading-w

[^6_20]: https://www.reddit.com/r/programming/comments/d4xx1/windows_dllloading_security_flaw_puts_microsoft/

[^6_21]: https://bugs.python.org/issue36085

[^6_22]: https://colinfay.me/r-installation-administration/add-on-packages.html

[^6_23]: https://community.alteryx.com/discussion/996509/r-package-error-unable-to-load-shared-object-vctrs-dll

[^6_24]: https://github.com/Rdatatable/data.table/issues/3056

[^6_25]: https://rstudio.github.io/r-manuals/r-admin/Add-on-packages.html

[^6_26]: https://rdrr.io/cran/pkgload/src/R/load-dll.R

[^6_27]: https://svn.r-project.org/R/branches/djm-tcltk/src/library/base/R/dynload.R

[^6_28]: https://www.reddit.com/r/learncpp/comments/unwwhs/how_do_programs_execute_with_dlls_in_separate/

[^6_29]: https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/dyn.load

[^6_30]: https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-redirection

[^6_31]: https://rdrr.io/r/base/library.dynam.html

[^6_32]: https://stackoverflow.com/questions/30034542/unable-to-load-any-package-in-r-unable-to-load-shared-object

[^6_33]: https://discourse.mc-stan.org/t/simple-stupid-problem-with-windows-rstan-suddenly-not-finding-dll-properly/24698

[^6_34]: https://stackoverflow.com/questions/38952571/how-to-load-custom-dll-in-r

[^6_35]: https://forum.posit.co/t/every-libraries-failed-to-load-after-upgrading-r-to-3-6-0/29736

[^6_36]: https://stat.ethz.ch/R-manual/R-devel/library/base/help/library.dynam.html

[^6_37]: https://github.com/RcppCore/Rcpp/issues/1095

[^6_38]: https://forum.posit.co/t/r-studio-package-installation-error-dyn-load-file-dllpath-dllpath/193962

[^6_39]: https://github.com/r-spatial/sf/discussions/2502

[^6_40]: https://wiki.tcl-lang.org/page/Extending+the+DLL+Search+Path+on+Windows

[^6_41]: https://ploomber.io/blog/shiny-sf-fix/

[^6_42]: https://forums.ni.com/t5/LabWindows-CVI/Giving-the-path-to-a-DLL-in-the-EXE/td-p/4434761

[^6_43]: https://stackoverflow.com/questions/51210587/sf-on-r-3-5-cant-find-correct-version-of-gdal

[^6_44]: https://www.rdocumentation.org/packages/terra/versions/0.2-8

[^6_45]: https://rspatial.github.io/terra/

[^6_46]: https://r-spatial.org/r/2020/03/17/wkt.html

[^6_47]: https://stackoverflow.com/questions/21662728/cant-load-a-dll-file-in-r-using-dyn-load-windows-7-64bit

[^6_48]: https://community.databricks.com/t5/data-engineering/unable-to-install-r-geospatial-libraries-raster-terra-sf-ncdf4/td-p/4723

[^6_49]: https://www.youtube.com/watch?v=2GNmhmoIiJs

[^6_50]: https://stackoverflow.com/questions/62820628/on-windows-is-it-possible-to-get-dlls-to-look-for-dependencies-in-another-folde

[^6_51]: https://andresrcs.rbind.io/2020/10/26/customizing_library_path/

[^6_52]: https://stat.ethz.ch/R-manual/R-patched/library/base/html/libPaths.html

[^6_53]: https://rdrr.io/cran/librarian/man/lib_startup.html

[^6_54]: https://docs.tibco.com/pub/enterprise-runtime-for-R/6.1.1/doc/html/Language_Reference/base/library.dynam.html

[^6_55]: https://www.reddit.com/r/cpp_questions/comments/1bc7hdh/change_dll_path_for_a_compiled_program/

[^6_56]: https://discourse.mc-stan.org/t/error-when-configuring-rstan-c-toolchain/17915

[^6_57]: https://ibob.bg/blog/2018/12/16/windows-rpath/

[^6_58]: https://forum.posit.co/t/problems-with-r-4-0-0-windows-error-package-or-namespace-load-failed-for-stats-in-indl-x-as-logical-local-as-logical-now/62958

[^6_59]: https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/library.dynam

[^6_60]: https://github.com/r-spatial/discuss/issues/31

[^6_61]: https://www.reddit.com/r/gis/comments/1517den/trouble_with_installing_gdal/

[^6_62]: https://gdal.org/en/stable/development/building_from_source.html

[^6_63]: https://github.com/astral-sh/uv/issues/11466

[^6_64]: https://geocompx.org/post/2023/rgdal-retirement/

[^6_65]: https://github.com/OSGeo/gdal/issues/5270

[^6_66]: https://cran.r-project.org/web/packages/gdalraster/readme/README.html

[^6_67]: https://cran.r-project.org/web/packages/gdalraster/gdalraster.pdf

[^6_68]: https://r-spatial.github.io/evolution/ogh23_bivand.html

[^6_69]: https://www.hypertidy.org/posts/2017-09-01_gdal-in-r/

[^6_70]: https://www.nuget.org/packages/MaxRev.Gdal.WindowsRuntime.Minimal

[^6_71]: https://stackoverflow.com/questions/34408699/having-trouble-installing-gdal-for-python-on-windows

[^6_72]: https://wiki.bwhpc.de/e/BwUniCluster2.0/Software/R/terra

[^6_73]: https://stackoverflow.com/questions/44973639/trouble-installing-sf-due-to-gdal

[^6_74]: https://rdrr.io/cran/terra/man/gdal.html

[^6_75]: https://www.reddit.com/r/rust/comments/1b2rlrs/quick_question_about_bundling_dll_files/

[^6_76]: http://hpc-community.unige.ch/t/problem-installing-sf-units-package-in-r-4-4-2/4143

[^6_77]: https://www.rdocumentation.org/packages/terra/versions/0.9-12

[^6_78]: https://github.com/rspatial/terra

[^6_79]: https://thinkr.fr/Installation_spatial_EN.html

[^6_80]: https://firelab.github.io/gdalraster/

[^6_81]: https://www.codeguru.com/windows/application-specific-paths-for-dll-loading/

[^6_82]: https://www.youtube.com/watch?v=4viTd3n9C9g

[^6_83]: https://rasterio.readthedocs.io/en/latest/topics/switch.html

[^6_84]: https://www.reddit.com/r/gis/comments/voafoy/how_do_i_successfully_install_gdal_on_windows/

[^6_85]: https://www.luisalucchese.com/post/solved-new-version-rasterio-gdal/

[^6_86]: https://www.hec.usace.army.mil/confluence/rasdocs/raski/latest/gdal-installation-issues

[^6_87]: https://gdal.org/en/stable/programs/gdalwarp.html

[^6_88]: https://stackoverflow.com/questions/63519334/how-can-i-link-r-packages-e-g-sf-or-mapview-to-the-latest-gdal-version

[^6_89]: https://rspatial.r-universe.dev/terra/doc/readme.html

[^6_90]: https://github.com/r-lib/withr

[^6_91]: https://www.rdocumentation.org/packages/sf/versions/0.1-3

[^6_92]: https://kbroman.org/pkg_primer/pages/build.html

[^6_93]: https://cran.r-project.org/package=sf

[^6_94]: https://www.facebook.com/groups/ecologyinr/posts/1531673064362250/

[^6_95]: https://stackoverflow.com/questions/1474081/how-do-i-install-an-r-package-from-source

[^6_96]: https://r-spatial.r-universe.dev/sf

[^6_97]: https://datascienceplus.com/how-to-make-and-share-an-r-package-in-3-steps/

[^6_98]: https://www.100daysofredteam.com/p/what-is-dll-search-order-and-how

[^6_99]: https://github.com/r-spatial/sf/issues/266

[^6_100]: https://github.com/rust-lang/rust/issues/56056

[^6_101]: https://www.reddit.com/r/gis/comments/1hojo4t/whats_the_point_of_pip_install_gdal_eli5/

[^6_102]: https://cran.r-project.org/package=gdalraster

[^6_103]: http://stefanoborini.com/windows-dll-search-path/

[^6_104]: https://stackoverflow.com/questions/11224123/load-time-dynamic-linking-import-library-search-order

[^6_105]: https://www.youtube.com/watch?v=tjNEoIYr_ag

[^6_106]: https://rasterio.readthedocs.io/en/stable/topics/switch.html

[^6_107]: https://github.com/OSGeo/gdal/issues/3368

[^6_108]: https://stackoverflow.com/questions/110249/building-and-deploying-dll-on-windows-sxs-manifests-and-all-that-jazz

[^6_109]: https://stackoverflow.com/questions/51367237/sf-r-package-is-not-compatible-with-gdal-versions-below-2-0-0-after-installing

[^6_110]: https://github.com/r-spatial/sf/issues/408

[^6_111]: https://discussions.unity.com/t/importing-gdal-from-nuget-package/757823

[^6_112]: https://pypi.org/project/GDAL/

[^6_113]: https://firelab.r-universe.dev/gdalraster

[^6_114]: https://gdal.org/en/stable/programs/gdal_raster_blend.html

[^6_115]: https://github.com/microsoft/vcpkg/discussions/36990

[^6_116]: https://cran.r-project.org/bin/windows/Rtools/rtools45/rtools.html

[^6_117]: https://www.rdocumentation.org/packages/utils/versions/3.6.2/topics/INSTALL

[^6_118]: https://stat.ethz.ch/R-manual/R-devel/library/utils/html/INSTALL.html

[^6_119]: https://cran.r-project.org/package=terra

[^6_120]: https://forums.opensuse.org/t/rstudio-dependencies-and-pkg-config/153749

[^6_121]: https://stackoverflow.com/questions/53279685/r-make-not-found-when-installing-a-r-package-from-local-tar-gz

[^6_122]: https://cran.r-project.org/bin/windows/base/howto-R-4.2.html

[^6_123]: https://stackoverflow.com/questions/75943925/how-to-fix-problem-with-installation-of-packages-raster-terra-rgdal-ra

[^6_124]: https://github.com/cran/rgdal/blob/master/inst/README.windows

[^6_125]: https://docs.alliancecan.ca/wiki/GDAL

[^6_126]: https://discourse.mc-stan.org/t/trouble-installing-rstan-on-windows/14773

[^6_127]: https://www.reddit.com/r/linux4noobs/comments/pybvdv/difference_between_binaries_and_libraries/

[^6_128]: https://forums.raspberrypi.com/viewtopic.php?t=204543

[^6_129]: https://www.jsoftware.com/help/user/dll_so.htm

[^6_130]: https://stackoverflow.com/questions/62415074/difference-between-shared-library-so-a-linux-executable-file-without-extensio

[^6_131]: https://en.wikipedia.org/wiki/Shared_library

[^6_132]: https://www.sandordargo.com/blog/2024/10/02/dynamic-vs-static-linking

[^6_133]: https://www.msys2.org/docs/environments/

[^6_134]: https://caiorss.github.io/C-Cpp-Notes/DLL-Binary-Components-SharedLibraries.html

[^6_135]: https://news.ycombinator.com/item?id=32531224

[^6_136]: https://stackoverflow.com/questions/1993390/static-linking-vs-dynamic-linking

[^6_137]: https://stackoverflow.com/questions/76552264/what-are-msys2-environments-how-do-i-pick-one

[^6_138]: https://github.com/databrickslabs/mosaic/issues/524

[^6_139]: https://github.com/caiorss/C-Cpp-Notes/blob/master/DLL-Binary-Components-SharedLibraries.org

[^6_140]: https://forum.dlang.org/thread/dobouzmhwabquswguunk@forum.dlang.org

[^6_141]: https://devinsights.iblogger.org/msys2-environment-differences/

[^6_142]: https://www.reddit.com/r/C_Programming/comments/1lw83ye/how_to_install_64bit_msys2_really/

[^6_143]: https://github.com/msys2/MSYS2-packages/discussions/4706

[^6_144]: https://stackoverflow.com/questions/15082060/set-up-a-msvc-dll-to-be-abi-compatible-to-a-stdcall-mingw-dll

[^6_145]: https://gitforwindows.org/the-difference-between-mingw-and-msys2.html

[^6_146]: https://ziggit.dev/t/windows-gnu-mingw-and-msvc-binary-c-abi-compatibility-guarantees/6903

[^6_147]: https://forum.crystal-lang.org/t/how-to-detect-the-current-msys2-environment-ucrt64-mingw64-clang64-on-windows/8090

[^6_148]: https://github.com/dotnet/sdk/issues/33845

[^6_149]: https://github.com/llvm/llvm-project/issues/60847

[^6_150]: https://github.com/microsoft/vscode-cpptools/issues/11063

[^6_151]: https://github.com/r-spatial/sf

[^6_152]: https://github.com/rspatial/terra/issues/487

[^6_153]: https://community.databricks.com/t5/data-engineering/install-r-package-quot-sf-quot/td-p/60090

[^6_154]: https://stackoverflow.com/questions/74575722/most-recent-terra-package-for-r-will-not-compile

[^6_155]: https://stackoverflow.com/questions/6009506/unable-to-install-python-and-gdal-dll-load-failed

[^6_156]: https://github.com/pyinstaller/pyinstaller/issues/1376

[^6_157]: https://github.com/r-spatial/sf/issues/2159

[^6_158]: https://cran.r-project.org/doc/manuals/r-release/R-exts.html

[^6_159]: https://stackoverflow.com/questions/315285/can-i-use-two-incompatible-versions-of-the-same-dll-in-the-same-process

[^6_160]: https://stackoverflow.com/questions/40634484/correct-installation-of-rtools-on-windows

[^6_161]: https://faims2-documentation.readthedocs.io/en/latest/Installing+GDAL+Tools+on+Windows/

[^6_162]: https://colinfay.me/writing-r-extensions/creating-r-packages-1.html

[^6_163]: https://gamedev.net/forums/topic/677890-dll-access-mechanism-between-multiple-applications/

[^6_164]: https://stackoverflow.com/questions/72386315/is-it-possible-for-a-process-to-load-two-dll-with-same-name-but-different-versio

[^6_165]: http://forum.vvvv.org/t/how-to-deal-with-different-versions-of-same-dll/14330

[^6_166]: https://learn.microsoft.com/en-us/answers/questions/5652481/how-to-use-multiple-dlls-with-the-same-name

[^6_167]: https://michaelscodingspot.com/dotnet-dll-hell/

[^6_168]: https://dev.to/johnnymakestuff/how-to-use-two-versions-of-the-same-dll-in-the-same-project-31db

[^6_169]: https://stackoverflow.com/questions/38698293/can-i-get-separate-dlls-to-resolve-their-imported-dlls-separately

[^6_170]: https://devnet.kentico.com/articles/referencing-multiple-versions-of-the-same-assembly-in-a-single-application

[^6_171]: https://www.reddit.com/r/csharp/comments/1h4qzte/is_a_dll_when_loaded_considered_as_another_process/

[^6_172]: http://mynameiskali.blogspot.com/p/c-20-using-different-versions-of-same_24.html

[^6_173]: https://rdrr.io/r/base/dynload.html

[^6_174]: https://forums.ni.com/t5/LabVIEW/Execute-multiple-versions-of-the-same-NET-DLL/td-p/4192116

[^6_175]: https://www.reddit.com/r/csharp/comments/10gvqki/why_are_there_different_versions_for_the_same_dll/

[^6_176]: https://stat.ethz.ch/R-manual/R-devel/library/base/help/dyn.load.html

[^6_177]: https://learn.microsoft.com/en-us/windows/win32/dlls/about-dynamic-link-libraries

