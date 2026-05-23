# AGENTS.md

## primary outcome

Enable `gdalraster` Algorithm API to work reliably from R on Windows.

Target user flow:

```r
pak::pak("jimbrig/gdalraster.windows")
gdalraster.windows::install_gdalraster()
gdalraster.windows::load_gdalraster()
gdalraster::gdal_global_reg_names()
```

Also support explicit load flow:

```r
gdalraster.windows::load_gdal_dll()
library(gdalraster)
gdalraster::gdal_global_reg_names()
```

## required system behavior

1. Build modern GDAL (currently 3.13+) from source in Windows CI using MSYS2 UCRT64 / Rtools45-compatible MinGW toolchain.
2. Build with required features for this project, including `muparser`, and keep runtime self-contained.
3. Produce a standalone GDAL runtime bundle archive with:
   - a top-level GDAL runtime DLL (`libgdal-*.dll`)
   - all required non-Windows dependent DLLs
   - required runtime data directories (`share/gdal`, `share/proj`)
4. Build `gdalraster` from source against that bundled GDAL runtime.
5. Ensure runtime loading is configured so `gdalraster` resolves bundled DLL dependencies at runtime (without relying on a matching user-installed Rtools environment).
6. Verify success with `gdalraster::gdal_global_reg_names()` returning non-empty output.

## source of truth

- CI workflow and scripts are authoritative for build/release behavior:
  - [`.github/workflows/build.yml`](.github/workflows/build.yml)
  - [`tools/build_gdal.sh`](tools/build_gdal.sh)
  - [`tools/collect_dlls.sh`](tools/collect_dlls.sh)
- `dev/temp` contains useful history, not production truth.

## execution priorities

1. Keep CI from-scratch builds green and reproducible.
2. Keep dependency-closure checks strict and meaningful.
3. Keep docs aligned with actual behavior.
4. Implement R helper ergonomics only after CI/runtime contract is stable.

## decision hygiene

- default to expert preflight before major changes:
  - likely failure modes
  - mitigation options and trade-offs
  - cache impact and rerun implications
  - confidence and unknowns
- do not assume repo notes are correct for external toolchain behavior; validate critical claims using upstream primary sources (official docs, release notes, upstream issues/PRs).
- when uncertain, label statements as provisional and ask for clarification instead of guessing.

## R package implementation constraints

- use modern package-style R with explicit namespacing.
- use `cli` for user-facing messaging and `cli::cli_abort()` for errors.
- use `rlang::caller_env()` and `rlang::caller_arg()` in validators/errors.
- use `withr` for scoped state (`with_makevars`, env vars, lib paths); avoid leaking persistent session/user config.
- default source-install target for `gdalraster` must be non-destructive (isolated library path), not overwrite existing user/global installs unless explicitly requested.

## editing conventions

- prefer focused, robust changes over one-off patches.
- keep comments sparse and practical.
- avoid destructive git operations unless explicitly requested.
- when behavior changes, update relevant docs in [`README.md`](README.md) and [`dev/docs/`](dev/docs) in the same change.
