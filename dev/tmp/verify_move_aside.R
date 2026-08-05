# repro of the self-lock overwrite failure, against a temp copy of the real
# runtime so the installed runtime is never touched. run with Rscript.

options(gdalraster.windows.auto_bootstrap = FALSE)
pkgload::load_all("D:/jimbrig/gdalraster.windows", export_all = FALSE, quiet = TRUE)

real_home <- gdalraster.windows::gdal_home()
stopifnot(dir.exists(file.path(real_home, "bin")))

root <- file.path(tempdir(), "move-aside-repro")
tmp_home <- file.path(root, "gdal")
dir.create(tmp_home, recursive = TRUE, showWarnings = FALSE)
ok <- file.copy(file.path(real_home, "bin"), tmp_home, recursive = TRUE)
stopifnot(isTRUE(ok))

# preload from the temp copy: maps libgdal + full dependency chain, exactly
# what the .onLoad auto-bootstrap did in the failing session
gdalraster.windows::activate_gdal_runtime(gdal_home = tmp_home, preload = TRUE, quiet = TRUE)
cat("preloaded runtime dlls:", length(gdalraster.windows:::loaded_runtime_dlls(tmp_home)), "\n")

# the failing session performed the release download via httr2/curl while the
# runtime bin dir was on PATH; replicate that so any curl/openssl dependency
# resolution against the runtime dir happens here too
invisible(tryCatch(
  httr2::req_perform(httr2::request("https://api.github.com")),
  error = function(e) NULL
))

# minimal replacement bundle zip
fixture_root <- file.path(root, "fixture")
dir.create(file.path(fixture_root, "bundle", "bin"), recursive = TRUE, showWarnings = FALSE)
writeLines("new", file.path(fixture_root, "bundle", "bin", "libgdal-39.dll"))
zip_path <- file.path(root, "bundle.zip")
old_wd <- setwd(fixture_root)
utils::zip(zipfile = zip_path, files = "bundle", flags = "-r9Xq")
setwd(old_wd)

gdalraster.windows::install_gdal_runtime(
  gdal_home = tmp_home,
  overwrite = TRUE,
  local_zip = zip_path
)

stopifnot(file.exists(file.path(tmp_home, "bin", "libgdal-39.dll")))
stopifnot(identical(readLines(file.path(tmp_home, "bin", "libgdal-39.dll")), "new"))

stale <- list.files(root, pattern = "^gdal\\.stale-", full.names = TRUE)
cat("stale dirs:", length(stale), "\n")
if (length(stale) == 1L) {
  moved <- list.files(stale, recursive = TRUE)
  cat("files moved aside:", length(moved), "\n")
  cat("zlib1 moved aside:", "bin/zlib1.dll" %in% moved, "\n")
}

# a later install must reclaim the stale dir once this process exits; here it
# is still pinned, so cleanup must silently leave it in place
gdalraster.windows:::cleanup_stale_runtimes(tmp_home)
cat("stale dir survives while pinned:", dir.exists(stale[1]), "\n")

cat("REPRO-OK\n")
