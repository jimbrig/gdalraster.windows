testthat::test_that("clean-room R session isolates startup and library paths", {
  testthat::skip_if_not(.Platform$OS.type == "windows")

  root <- withr::local_tempdir()
  env <- clean_room_env(root)

  code <- paste(
    "cat('R_PROFILE_USER=', Sys.getenv('R_PROFILE_USER'), '\\n', sep = '')",
    "cat('R_ENVIRON_USER=', Sys.getenv('R_ENVIRON_USER'), '\\n', sep = '')",
    "cat('HOME=', normalizePath(Sys.getenv('HOME'), winslash = '/', mustWork = FALSE), '\\n', sep = '')",
    "cat('R_LIBS_USER=', normalizePath(Sys.getenv('R_LIBS_USER'), winslash = '/', mustWork = FALSE), '\\n', sep = '')",
    "cat('LIBPATHS=', paste(normalizePath(.libPaths(), winslash = '/', mustWork = FALSE), collapse = '|'), '\\n', sep = '')",
    sep = "; "
  )

  res <- run_clean_rscript(code = code, env = env)
  txt <- paste(c(res$stdout, res$stderr), collapse = "\n")

  testthat::expect_equal(res$status, 0)
  testthat::expect_match(txt, "R_PROFILE_USER=NUL", fixed = TRUE)
  testthat::expect_match(txt, "R_ENVIRON_USER=NUL", fixed = TRUE)
  testthat::expect_match(
    txt,
    paste0("R_LIBS_USER=", normalizePath(file.path(root, "lib"), winslash = "/", mustWork = FALSE)),
    fixed = TRUE
  )
})

testthat::test_that("opt-in full e2e succeeds in clean room", {
  testthat::skip_if_not(.Platform$OS.type == "windows")
  testthat::skip_if_not(identical(tolower(Sys.getenv("GDALRASTER_WINDOWS_RUN_E2E", "false")), "true"))

  root <- withr::local_tempdir()
  env <- clean_room_env(root)

  code <- paste(
    ".libPaths(c(Sys.getenv('R_LIBS_USER'), .libPaths()))",
    "stopifnot(requireNamespace('gdalraster.windows', quietly = TRUE))",
    "gdalraster.windows::install_gdal_runtime(gdal_home = Sys.getenv('GDALRASTER_WINDOWS_GDAL_HOME'), overwrite = TRUE)",
    "gdalraster.windows::install_gdalraster(gdal_home = Sys.getenv('GDALRASTER_WINDOWS_GDAL_HOME'), lib = Sys.getenv('R_LIBS_USER'), upgrade = TRUE)",
    "gdalraster.windows::load_gdalraster(lib = Sys.getenv('R_LIBS_USER'), gdal_home = Sys.getenv('GDALRASTER_WINDOWS_GDAL_HOME'), quiet = TRUE)",
    "algs <- gdalraster::gdal_global_reg_names()",
    "cat('algorithm_count=', length(algs), '\\n', sep = '')",
    "stopifnot(length(algs) > 0L)",
    sep = "; "
  )

  res <- run_clean_rscript(code = code, env = env)
  txt <- paste(c(res$stdout, res$stderr), collapse = "\n")

  testthat::expect_equal(res$status, 0, info = txt)
  testthat::expect_match(txt, "algorithm_count=", fixed = TRUE)
})
