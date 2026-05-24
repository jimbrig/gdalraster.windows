clean_room_env <- function(root) {
  home <- file.path(root, "home")
  lib <- file.path(root, "lib")
  gdal <- file.path(root, "gdal")

  dir.create(home, recursive = TRUE, showWarnings = FALSE)
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  dir.create(gdal, recursive = TRUE, showWarnings = FALSE)

  path_sep <- .Platform$path.sep
  path_parts <- strsplit(Sys.getenv("PATH", unset = ""), path_sep, fixed = TRUE)[[1]]
  path_parts <- path_parts[nzchar(path_parts)]
  path_parts <- path_parts[!grepl("rtools45|gdal-ucrt64", path_parts, ignore.case = TRUE)]
  path_clean <- paste(path_parts, collapse = path_sep)

  c(
    R_PROFILE_USER = "NUL",
    R_ENVIRON_USER = "NUL",
    HOME = normalizePath(home, winslash = "/", mustWork = FALSE),
    R_LIBS_USER = normalizePath(lib, winslash = "/", mustWork = FALSE),
    GDALRASTER_WINDOWS_GDAL_HOME = normalizePath(gdal, winslash = "/", mustWork = FALSE),
    PATH = path_clean
  )
}

run_clean_rscript <- function(code, env) {
  out <- withr::local_tempfile(fileext = ".txt")
  err <- withr::local_tempfile(fileext = ".txt")
  script <- withr::local_tempfile(fileext = ".R")
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  if (!file.exists(rscript)) {
    rscript <- Sys.which("Rscript")
  }
  writeLines(code, con = script, useBytes = TRUE)

  status <- withr::with_envvar(
    env,
    system2(
      command = rscript,
      args = c("--vanilla", script),
      stdout = out,
      stderr = err,
      wait = TRUE
    )
  )

  list(
    status = status,
    stdout = if (file.exists(out)) readLines(out, warn = FALSE) else character(),
    stderr = if (file.exists(err)) readLines(err, warn = FALSE) else character()
  )
}
