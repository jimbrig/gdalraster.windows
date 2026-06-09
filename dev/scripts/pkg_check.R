
#  ------------------------------------------------------------------------
#
# Title : Package Check
#    By : Jimmy Briggs
#  Date : 2026-06-02
#
#  ------------------------------------------------------------------------

check <- local({
  pkg_path <- this.path::this.proj()
  check_path <- file.path(pkg_path, "dev/check")
  if (dir.exists(check_path)) fs::dir_delete(check_path)
  dir.create(check_path, recursive = TRUE, showWarnings = FALSE)
  usethis::use_git_ignore(ignores = c("*", "!.gitignore"), directory = "dev/check")
  attachment::att_amend_desc()
  check <- rcmdcheck::rcmdcheck(path = pkg_path, check_dir = check_path, args = c("--no-examples", "--no-tests"), error_on = "never")
  cli::cli_alert_success("R CMD CHECK completed")
  check
})
