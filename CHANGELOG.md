# Changelog

> All notable changes to this project will be documented in this file. The format is based on
[Keep a Changelog](http://keepachangelog.com/) and this project adheres to
[Semantic Versioning](http://semver.org/).

## [Unreleased]

## DevOps

- **pkgdown:** Add GitHub Actions workflow to build and deploy pkgdown site ([3922d9e](https://github.com/jimbrig/gdalraster.windows/commit/3922d9e1f796f71572b08883130037f7192caa11))  - (Jimmy Briggs)
- **workflows:** Add R CMD CHECK workflow and update README badges ([b023b98](https://github.com/jimbrig/gdalraster.windows/commit/b023b98955c14f52f4cf618821e2eb5386134f28))  - (Jimmy Briggs)
- **changelog:** Run changelog workflow on pushes/PRs and bump actions versions ([bbb711a](https://github.com/jimbrig/gdalraster.windows/commit/bbb711a3900d959019c24319a150471aacdd5157))  - (Jimmy Briggs)
- Add Windows R CMD CHECK workflow ([44a366c](https://github.com/jimbrig/gdalraster.windows/commit/44a366c281e98ecef759513d481be49d77a8035e))  - (Jimmy Briggs)

## Documentation

- **readme:** Fix R CMD CHECK badge link and add pkgdown badge ([10fee19](https://github.com/jimbrig/gdalraster.windows/commit/10fee19e7de30ca80c177be3235c31fbc2183075))  - (Jimmy Briggs)
- Rewrite README with comprehensive Windows GDAL runtime guide ([e9de2e9](https://github.com/jimbrig/gdalraster.windows/commit/e9de2e99ebea68cb6861042b9aaaf6e55cef3a26))  - (Jimmy Briggs)
- Add in-depth Windows GDAL runtime guides and update package docs ([0fac782](https://github.com/jimbrig/gdalraster.windows/commit/0fac7829cb0e58d53cc0445de057589fc3617064))  - (Jimmy Briggs)

## Features

- Bundle pure-python osgeo_utils and expose via PYTHONPATH at runtime activation ([3cba16f](https://github.com/jimbrig/gdalraster.windows/commit/3cba16f5b22b0e881ff11479dfed2582d2cb84e1))  - (Jimmy Briggs)
- **startup:** Add runtime bootstrap and startup sitrep, streamline verification ([77048b3](https://github.com/jimbrig/gdalraster.windows/commit/77048b34ad9be25ccb2b136aa78299db352b2645))  - (Jimmy Briggs)
  - **BREAKING CHANGE:** option and API changes:
- Option renamed: gdalraster.windows.auto_activate → gdalraster.windows.auto_bootstrap
- verify_gdalraster_runtime signature/behavior changed: now returns TRUE/FALSE (not a list)
  and accepts a new quiet argument; callers relying on the old return structure must be updated.
- Startup sitrep display is now controlled by options(gdalraster.windows.startup.sitrep).
- **startup:** Add .Rprofile hook to preload GDAL DLL and manage gdalraster lib ([5a55159](https://github.com/jimbrig/gdalraster.windows/commit/5a55159d192b36b9b747dfac6a85fa5ceefb5d4f))  - (Jimmy Briggs)
- **gdal:** Add local and fallback zip support to install_gdal_runtime ([a4c1445](https://github.com/jimbrig/gdalraster.windows/commit/a4c1445cd5f11b70ee5dc08f2aa1793020d7a9e2))  - (Jimmy Briggs)

## Testing

- Add Windows clean-room e2e tests, helpers, and README docs ([a0378d0](https://github.com/jimbrig/gdalraster.windows/commit/a0378d034f048713d2dde5088dab3934cb0a4ab3))  - (Jimmy Briggs)

## [gdal-v3.13.0](https://github.com/jimbrig/gdalraster.windows/tree/gdal-v3.13.0)- (2026-05-23)

## Bug Fixes

- **gdalraster:** Add --no-test-load to source install to avoid test-load failures ([326f2c2](https://github.com/jimbrig/gdalraster.windows/commit/326f2c2d752729abac7770e8ee2010c682adbc45))  - (Jimmy Briggs)
- **gdalraster:** Make source install more robust and improve error reporting ([0202c66](https://github.com/jimbrig/gdalraster.windows/commit/0202c6684b19440dfe3d07c1c879fac2729d664b))  - (Jimmy Briggs)
- **ci:** Run R CMD INSTALL via Rscript system2 ([116f093](https://github.com/jimbrig/gdalraster.windows/commit/116f093020cd110f9f8bf18edfd90d6ff67683ff))  - (Jimmy Briggs)
- **ci:** Make dependency leak gate bundle-aware ([35c4f0d](https://github.com/jimbrig/gdalraster.windows/commit/35c4f0d3159791f98e0e829513ae3c18f08ace6b))  - (Jimmy Briggs)
- **ci:** Use valid MSYS2 libspatialite package name ([b0aa88b](https://github.com/jimbrig/gdalraster.windows/commit/b0aa88b0b8afd6d4e5224b18a23a9e4811ce5db8))  - (Jimmy Briggs)
- **ci:** Harden ntldd dependency parsing in collect step ([693ca2d](https://github.com/jimbrig/gdalraster.windows/commit/693ca2d81ccee449ab05b5cd11918e9892cabe06))  - (Jimmy Briggs)
- **ci:** Harden GDAL workflow for portable runtime validation ([c24abe7](https://github.com/jimbrig/gdalraster.windows/commit/c24abe76cba921c16f3864550f234cf6dc631a8d))  - (Jimmy Briggs)
- **ci:** Align GDAL workflow with validated dependency closure ([db5b717](https://github.com/jimbrig/gdalraster.windows/commit/db5b7175e496a116979f88a66fd0aeadb31058c7))  - (Jimmy Briggs)
- Add missing MSYS2 deps (PROJ, libxml2, xerces-c, deflate, tiff, geotiff, curl, sqlite, zlib) and fix hardcoded R.exe paths ([ec26905](https://github.com/jimbrig/gdalraster.windows/commit/ec269050599acaefea9c3b97e59a89a97f4ff94d))  - (Jimmy Briggs)
- Update GDAL build scripts and paths ([2280f93](https://github.com/jimbrig/gdalraster.windows/commit/2280f9390283acea96513f9dc0442de062435241))  - (Jimmy Briggs)

## Configuration

- **.cursor:** Add MCP server config and scaffold cursor directories ([84318da](https://github.com/jimbrig/gdalraster.windows/commit/84318dac52e12ee4a2d56348509584796aa6901c))  - (Jimmy Briggs)

## Documentation

- Refresh maintainer docs, AGENTS guidance, and README ([e7beb45](https://github.com/jimbrig/gdalraster.windows/commit/e7beb450ef387a3d2b4bddddc1d0d9c58f62156e))  - (Jimmy Briggs)
- Add curated maintainer docs and overhaul top-level README ([bbd3a74](https://github.com/jimbrig/gdalraster.windows/commit/bbd3a74073a770c4dadb65e1199b61edfee44245))  - (Jimmy Briggs)
- **changelog:** Add GitHub Action to generate and push CHANGELOG.md ([3da74a8](https://github.com/jimbrig/gdalraster.windows/commit/3da74a8d35e926cca2b674d38225091f61ff67c2))  - (Jimmy Briggs)

## Features

- **gdal:** Add local and fallback zip support to install_gdal_runtime ([74a069f](https://github.com/jimbrig/gdalraster.windows/commit/74a069fcedebe396e29b10abfebaefd453aaebd8))  - (Jimmy Briggs)
- **gdalraster:** Add install/load helpers and dynamic GDAL DLL discovery ([de9e869](https://github.com/jimbrig/gdalraster.windows/commit/de9e86937a73c57cf4dbc89c7643c744335feb1b))  - (Jimmy Briggs)
- **docs:** Add Rd man pages and update DESCRIPTION & NAMESPACE ([46376e6](https://github.com/jimbrig/gdalraster.windows/commit/46376e64b697ce6124d6ae214a84d1c5a93c26b3))  - (Jimmy Briggs)
- Add Windows GDAL runtime wrapper package and CI to build GDAL and R binaries ([373663f](https://github.com/jimbrig/gdalraster.windows/commit/373663f92ea73b7368c5f57b607026e47ae84b64))  - (Jimmy Briggs)

***
*Changelog generated by [git-cliff](https://github.com/orhun/git-cliff).*
***
