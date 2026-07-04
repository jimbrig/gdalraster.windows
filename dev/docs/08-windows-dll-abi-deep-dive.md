# windows dll loading and abi deep dive

> [!NOTE]
> Learning-oriented deep dive written after the July 2026 e2e failure
> investigation. It uses this project's real failures as case studies to
> explain how compilation, linking, DLL loading, and ABI compatibility
> actually work on Windows — and why the MinGW/UCRT/CMake path is more
> nuanced than MSVC. Non-normative; see `vignettes/architecture.qmd` for the
> canonical user-facing material.

## 1. the pipeline: compile → link → load

Three distinct phases, each with its own failure modes. Most confusion comes
from conflating them.

### compile

Source files become object files (`.o`). The compiler only needs *headers*.
Nothing about DLLs matters yet. A successful compile proves the API
(declarations) matched — nothing more.

### link

The linker (`ld` in MinGW, `link.exe` in MSVC) combines object files and
resolves symbol references. For every symbol your code uses, the linker must
find a definition in either:

- another object file / static library (`.a`, `.lib`) — the code is copied
  into your binary, or
- an **import library** (`.dll.a` in MinGW, `.lib` in MSVC) — a thin stub
  that says "this symbol lives in `libgdal-39.dll`; emit an import table
  entry for it."

The output DLL/EXE therefore contains an **import table**: a list of
`(dll base name, symbol)` pairs. Inspect it with:

```bash
objdump -p libgdal-39.dll | grep "DLL Name"
```

Key point: the import table records only the **base name** (`libpodofo.dll`),
never a path. Where the file comes from at runtime is decided entirely by the
loader (section 2).

Windows-specific link concerns handled in `tools/build_gdal.sh`:

- **exports and ordinals** — a PE DLL exposes symbols through an export
  table capped at 65,535 ordinals. GDAL's full C++ symbol set exceeds that,
  hence `-DGDAL_HIDE_INTERNAL_SYMBOLS=ON` (see
  [OSGeo/gdal#4706](https://github.com/OSGeo/gdal/issues/4706)). MSVC
  builds hit the same limit but the default there is already to export
  nothing unless annotated — MinGW's default (export everything) is what
  creates the pressure.
- **`-Wl,--kill-at`** — MinGW decorates `__stdcall` exports as `name@N`;
  this strips the decoration so lookups by plain name succeed.
- **static runtime embedding** — `-static-libgcc -static-libstdc++` plus
  whole-archive `winpthread` copies the GCC runtime *into* `libgdal`, so the
  DLL doesn't import `libgcc_s_seh-1.dll`/`libstdc++-6.dll` at all.
  (Compare: the manual `C:/gdal-ucrt64` build from
  [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982)
  did not use these flags and imports all three dynamically from
  `C:/rtools45/ucrt64/bin`.)

### load

At `LoadLibrary` time (which is what R's `dyn.load()` calls), the Windows
loader:

1. reads the import table of the requested DLL
2. recursively resolves every dependency (section 2)
3. maps them all into the process
4. runs each module's **`DllMain`** initialization (section 3)

Steps 2 and 4 are where every failure in this project has lived. A build
that compiles and links perfectly can still fail both.

## 2. how the loader resolves dependencies

For each base name in the import table:

1. **already-loaded module list** — if a module with that base name is
   already in the process, it is reused. Full stop. This is the
   "first-loaded wins" rule: once *any* `libgdal-39.dll` is loaded, every
   later request for `libgdal-39.dll` gets that copy, regardless of PATH.
   This is why mixing the manual `C:/gdal-ucrt64` stack and the
   package-managed bundle in one R session is dangerous.
2. **API sets** — names like `api-ms-win-crt-heap-l1-1-0.dll` are virtual;
   the loader maps them to the real UCRT (`ucrtbase.dll`) via the API set
   schema. They always resolve on supported Windows; never bundle them.
3. **search order** — application directory, `System32`, the `PATH`
   entries, in order. R packages rely on `PATH` (or
   `AddDllDirectory`-style mechanisms), which is why
   `activate_gdal_runtime()` prepends `<gdal_home>/bin` to `PATH` before
   anything touches GDAL.

Failure at this stage → `LoadLibrary failure: The specified module could not
be found.` (Win32 error 126). Note the misleading message: it names the DLL
you *asked for*, not the missing transitive dependency five levels down.
`ntldd -R` (or a manual BFS over `objdump -p` output) is how you find the
real culprit.

## 3. DllMain, static initializers, and error 1114

After mapping, each module gets a `DllMain(DLL_PROCESS_ATTACH)` call — made
while the loader holds the global **loader lock**. For C++ DLLs, this is
also when all namespace-scope constructors ("static initializers") run.

If `DllMain` returns `FALSE` or an initializer throws, the *entire*
`LoadLibrary` call fails with Win32 error 1114:

```
LoadLibrary failure: A dynamic link library (DLL) initialization routine failed.
```

Properties that make this failure class nasty:

- **import scanning cannot detect it.** The dependency exists, resolves,
  and maps fine. `ntldd` reports a perfectly closed bundle. Only actually
  loading the DLL reveals it. This is exactly why `build.yml` now has a
  LoadLibrary smoke-test step over every bundled DLL, in addition to the
  `ntldd` closure check.
- **it can be environment- and dependency-version-dependent.** Whatever the
  initializer does (open files, initialize crypto, query fonts) depends on
  process state and on which copies of *its* dependencies got loaded.
- **one bad module poisons the root load.** `libgdal` imports `libpodofo`
  directly, so podofo's failed init makes `libgdal` itself unloadable, even
  though 174 of the bundle's 175 DLLs are fine.

### case study: the podofo × libcrypto failure (July 2026)

Observed: published bundle's `libgdal-39.dll` fails with 1114 everywhere —
clean CI runners *and* the dev machine, R sessions *and* plain PowerShell.

Isolation (sweep-`LoadLibrary` every bundled DLL individually): only
`libpodofo.dll` fails. Its imports all load fine individually. The binary is
**byte-identical** (same SHA-256) to `C:/rtools45/ucrt64/bin/libpodofo.dll`,
which loads fine.

The difference: which `libcrypto-3-x64.dll` is in the process. PoDoFo runs
OpenSSL initialization inside its static initializers (under the loader
lock). Against Rtools45's libcrypto it succeeds; against the MSYS2-bundle
libcrypto builds shipped in the June and July bundles it fails. Preloading
Rtools45's libcrypto before loading the bundle's podofo makes everything
load — same podofo bytes, different outcome.

Resolution: the PDF driver is disabled outright
(`-DGDAL_ENABLE_DRIVER_PDF=OFF` plus `GDAL_USE_POPPLER/PODOFO/PDFIUM=OFF`).
Disabling only poppler is insufficient because the PDF driver silently falls
back to the podofo backend.

Moral: *a DLL is not a pure function of its bytes.* Its load behavior
depends on the dependency graph the process resolves for it.

## 4. C ABI vs C++ ABI

### C: a de facto stable ABI

C has a small, conventional binary interface per platform: fixed calling
conventions, no name mangling (or trivial decoration), struct layout rules
everyone agrees on. This is why every FFI in existence (R's `.Call`, Python
ctypes, etc.) targets C, and why GDAL's *C API* (`gdal.h`, `ogr_api.h`) is
consumable from any compiler. If `gdalraster` used only GDAL's C API, an
MSVC-built GDAL DLL would in principle be linkable from MinGW-built R code.

### C++: no standard ABI at all

The C++ standard deliberately does not define a binary interface. Each
compiler family invents its own for:

- **name mangling** — GCC/MinGW uses the Itanium C++ ABI scheme
  (`_ZN4gdal...`), MSVC uses its own (`?name@class@@...`). Symbols from one
  simply do not exist under the other's names, so cross-linking fails at
  link time — the *good* outcome.
- **class layout** — vtable structure, virtual base offsets, member
  ordering, empty-base optimization details.
- **exception handling** — MSVC uses SEH-based C++ exceptions; MinGW x86_64
  uses SEH frames too but with GCC's own personality routines; an exception
  thrown by one runtime cannot be caught by the other.
- **standard library types** — `std::string`/`std::vector` from MSVC's STL
  and GCC's libstdc++ are different types with different layouts and
  different allocators. Passing them across a compiler boundary is undefined
  behavior even when everything links.
- **heap/CRT coupling** — memory allocated by one CRT must be freed by the
  same CRT. Cross-runtime `new`/`delete` corrupts heaps.

`gdalraster` binds GDAL's **C++ API** (Algorithm API classes and more).
Therefore GDAL and `gdalraster` must be built by the *same compiler family
with compatible versions and the same CRT*. This single fact drives the
whole architecture of this repo: MinGW UCRT64 GDAL + Rtools45 (also MinGW
UCRT64) gdalraster, and never a prebuilt MSVC GDAL.

GCC's own C++ ABI is stable-ish across versions (libstdc++ keeps backward
compatibility), which is why an MSYS2 GCC 16 GDAL links from an Rtools45 GCC
14 gdalraster build — same mangling scheme, same libstdc++ family. The
residual risk is forward-compat (old libstdc++ asked to satisfy new-GCC
symbols), which static-linking libstdc++ into `libgdal` sidesteps.

### the CRT dimension: msvcrt vs ucrt

Windows historically had two C runtimes for MinGW targets:

- `MSVCRT` — the ancient `msvcrt.dll`; MINGW64 environment targets it
- `UCRT` — the modern Universal C Runtime; UCRT64 environment and all of
  MSVC target it

R ≥ 4.2 and Rtools42+ are UCRT. Everything in one process should share one
CRT (per module; statically embedded copies are fine because their state is
module-private). This repo pins UCRT64 everywhere. A MINGW64 (msvcrt) GDAL
under a UCRT R would be a subtle-corruption machine.

## 5. why mingw + cmake feels harder than msvc

It isn't the compiler that's harder — it's the *distribution model*.

| Concern | MSVC world (e.g. conda-forge/pixi) | MinGW/MSYS2 world (this repo) |
|---|---|---|
| Who assembles dependencies | Package manager with solver; a curated, mutually consistent set is installed per environment | `pacman` on a rolling release; whatever is in `/ucrt64` today is what cmake finds |
| Dependency detection | Same — cmake `find_package` — but the env contains only what you requested | cmake auto-detects *everything present*, including deps of unrelated packages (the MSYS2 `gdal` package's own dep tree: podofo, poppler, hdf4, …) |
| Runtime redistribution | Environment ships every DLL; activation sets PATH | You build the closure yourself (`collect_dlls.sh` + `ntldd`) |
| Version skew | Solver prevents mixing incompatible builds | CI MSYS2 vs local Rtools45 snapshot vs last month's CI can all differ (the libcrypto that broke podofo) |
| ABI for R packages | **Unusable** — R/Rtools is MinGW; MSVC C++ ABI is incompatible | Native fit — same toolchain family as Rtools |

So the trade is forced: R's Windows toolchain is MinGW, `gdalraster` needs
GDAL's C++ ABI, therefore GDAL must be MinGW-built — and with MinGW you
inherit MSYS2's rolling-release packaging and DIY runtime closure.

Concrete manifestations in this repo:

- **auto-detection surprises**: CI runners had the MSSQL ODBC SDK installed
  → GDAL silently linked `msodbcsql17.dll` (issue #13). MSYS2's `gdal`
  package transitively installs podofo/poppler → the PDF driver got built
  against them even though we never asked. Countermeasures: explicit
  `GDAL_USE_*=OFF` / `GDAL_ENABLE_DRIVER_*=OFF` flags, plus the banned-DLL
  guard in `collect_dlls.sh`.
- **"present in the build env ≠ present on user machines"**: everything
  that resolves from `/ucrt64` at build time must be bundled or excluded.
- **"bundled ≠ loadable"**: closure verification (`ntldd`) is necessary but
  not sufficient; the smoke-load gate covers DllMain failures.

## 6. the pixi/conda GDAL on this machine

`where.exe gdal` → `C:\Users\jimmy\.pixi\bin\gdal.exe` is a conda-forge
build: MSVC compiler, UCRT (all MSVC software is UCRT), dependencies managed
by the conda solver inside the pixi environment.

- It is a great *CLI* GDAL and completely healthy to keep.
- It can never back `gdalraster` (or `sf`/`terra` source builds): MSVC C++
  ABI + MSVC import libraries (`gdal_i.lib`) are unusable from Rtools'
  MinGW toolchain (different mangling, different exception model,
  different STL).
- Coexistence is safe *between processes*. Within an R process, the only
  hazard is base-name collision (`gdal.exe`'s DLLs are named like
  `gdal.dll`, not `libgdal-39.dll`, so in practice they don't collide with
  the MinGW stack — but keep `.pixi/bin` *after* the GDAL runtime dirs in
  any PATH an R session uses).
- R packages from CRAN binaries (sf, terra, vapour) avoid all of this by
  statically linking their own GDAL *into* the package DLL — no shared
  `libgdal` at all, at the cost of no Algorithm API and duplicated code in
  memory. That's the design this repo's shared-runtime approach trades
  against, to get GDAL 3.13 + muparser + Arrow into `gdalraster`.

## 7. failure-class cheat sheet

| Symptom | Win32 error | Phase | Cause pattern | Diagnostic |
|---|---|---|---|---|
| `specified module could not be found` | 126 | dependency resolution | a *transitive* dep isn't on the search path (message names the root DLL, not the missing one) | `ntldd -R`, or `objdump -p` BFS; check PATH at the moment of load |
| `DLL initialization routine failed` | 1114 | DllMain | static initializer failed; often depends on *which copy* of a dependency got resolved | per-DLL `LoadLibrary` sweep; bisect by preloading alternate dependency copies |
| `%1 is not a valid Win32 application` | 193 | mapping | 32/64-bit mismatch or corrupt file | `objdump -f` (check `x86-64`) |
| entry point not found | 127 | symbol binding | version skew: DLL found, but lacks an export the importer expects | `objdump -p` exports vs imports diff |
| links fine, crashes at runtime | — | ABI | C++ ABI/CRT mismatch (wrong toolchain pairing) | check compiler provenance of every module in the process |

## 8. verification toolbox

What each tool proves — and what it cannot:

- `objdump -p X.dll | grep "DLL Name"` — direct imports only. Fast, static.
  Cannot see transitive deps, delay-loads via `LoadLibrary` calls in code,
  or init failures.
- `ntldd -R X.dll` — recursive resolution using the *current environment's*
  PATH. Proves closure **for the machine and PATH you run it on** (this is
  why `ntldd-local.txt` from 2026-05-23 shows everything resolving to
  `C:\rtools45\ucrt64\bin` — that walk validated the dev machine, not a
  clean one). Cannot detect DllMain failures.
- `LoadLibrary` smoke test (now step 7b in `build.yml`) — proves every
  bundled DLL actually initializes in a plain process on a clean runner.
  Cannot prove R-session behavior or functional correctness.
- `dyn.load(dll, local = FALSE, now = TRUE)` in R — same as above but in
  the real consumer process, with R's own loaded-module state.
- e2e workflow — the only thing that proves the full documented user flow
  (`install_gdal_runtime()` → `install_gdalraster()` →
  `gdal_global_reg_names()` → `.Rprofile` hook) on a machine with no
  Rtools/MSYS2 leakage.

Layered together these now gate every release: import closure (`ntldd` +
banned-DLL regex) → loadability (smoke test) → functionality (e2e on
release publish).

## 9. project failure history in one table

| Date | Failure | Class | Fix |
|---|---|---|---|
| 2026-05 (pre-repo, #982) | `character(0)` from `gdal_global_reg_names()` | build composition (no muparser in Rtools GDAL) | custom GDAL with `GDAL_USE_MUPARSER=ON` |
| 2026-05 | `module could not be found` at load | runtime search path | PATH activation + DLL preload (`activate_gdal_runtime()`) |
| 2026-06 (#13) | bundle worked in CI, failed on user machine | env-leak linkage: `msodbcsql17.dll` auto-detected on runner + verifier allowlisted System32 blanketly | `GDAL_USE_MSSQL_ODBC/NCLI=OFF`; `denied_system_regex` in verifier |
| 2026-07 (e2e, PR #22 era) | error 1114 on every clean machine | DllMain failure: podofo static init × MSYS2 libcrypto | `GDAL_ENABLE_DRIVER_PDF=OFF` (+ all PDF backends off); banned-DLL guard; LoadLibrary smoke gate in CI |

Misdiagnosis note: PR #22 attributed the 1114 to an HDF5 → OpenBLAS →
libgfortran/libgomp conflict with DLLs "already loaded by R". Empirical
testing (loading all 175 bundle DLLs individually inside R 4.6.1) disproved
this — the entire HDF5/OpenBLAS/Fortran chain loads cleanly, and R does not
pin conflicting copies of those DLLs at startup. HDF5/NetCDF are therefore
enabled in the build. The lesson generalizes: on Windows DLL questions,
prefer a 10-minute empirical `LoadLibrary` bisect over dependency-graph
theorizing; the loader has too many moving parts to reason about reliably
from static inspection alone.

## 10. further reading

- Windows loader search order: Microsoft "Dynamic-link library search order"
- DllMain constraints: Microsoft "Dynamic-Link Library Best Practices"
  (why nontrivial work under the loader lock is dangerous — the exact trap
  podofo fell into)
- Itanium C++ ABI (the spec GCC/MinGW mangling follows)
- MSYS2 environments documentation (UCRT64 vs MINGW64 vs CLANG64)
- R Installation and Administration manual, "The Windows toolchain" (UCRT
  transition in R 4.2)
- GDAL building-from-source docs (driver/`GDAL_USE_*` option semantics)
