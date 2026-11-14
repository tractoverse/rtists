# ---- Shiny demo launcher -----------------------------------------------------

# Locate the rtists source-tree root. The `demo/` folder is Rbuildignored and so
# is NOT shipped with the installed/built package; these utilities therefore only
# work from a source checkout (after devtools::load_all() or from the repository
# root). We resolve the root without a hard dependency on pkgload/rprojroot by
# walking up from the working directory to the first `DESCRIPTION` declaring
# `Package: rtists`.
# The demo launcher runs an interactive Shiny app that blocks until the app
# is closed, so it is not unit-testable and is excluded from coverage.
# nocov start
.rtists_source_root <- function() {
  here <- getwd()
  repeat {
    desc <- file.path(here, "DESCRIPTION")
    if (file.exists(desc)) {
      pkg <- tryCatch(
        read.dcf(desc, fields = "Package")[1L],
        error = function(e) NA_character_
      )
      if (!is.na(pkg) && identical(pkg, "rtists")) {
        return(here)
      }
    }
    parent <- dirname(here)
    if (identical(parent, here)) break
    here <- parent
  }
  stop(
    "Could not locate the rtists source tree (no DESCRIPTION declaring ",
    "`Package: rtists` found above the working directory). ",
    "The `demo/` folder only ships in a source checkout; run from the ",
    "repository root or after devtools::load_all().",
    call. = FALSE
  )
}

#' Launch an interactive rtists Shiny demo
#'
#' Starts one of the Shiny demo apps shipped in the rtists source tree under
#' `demo/<name>/` using [shiny::runApp()]. The demos exercise the three.js
#' r186 htmlwidget in a live app and double as an end-to-end check of the
#' asynchronous ESM loader.
#'
#' Because `demo/` is excluded from the built package (see `.Rbuildignore`),
#' this helper is only available from a **source checkout** of rtists — i.e.
#' after [devtools::load_all()] or when the working directory is inside the
#' repository. There is currently one demo:
#'
#' - `"line2"`: a synthetic bundle rendered both in the default `Line2` mode and
#'   as variable-radius tubes (radial-displacement path).
#'
#' @param name Character. Name of a demo app; must match a subfolder of
#'   `demo/` in the repository root. Defaults to `"line2"`.
#' @param ... Additional arguments passed on to [shiny::runApp()] (e.g. `port`,
#'   `host`, `launch.browser`).
#'
#' @return `TRUE` invisibly once the app session ends (the app itself blocks
#'   until closed).
#' @export
#'
#' @examples
#' \dontrun{
#' # from the repository root or after devtools::load_all()
#' rtists::runDemo("line2")
#' }
runDemo <- function(name = "line2", ...) {
  root <- .rtists_source_root()
  dir  <- file.path(root, "demo", name)
  if (!file.exists(file.path(dir, "app.R"))) {
    stop("Demo app not found: ", dir, call. = FALSE)
  }
  # Shiny is a Suggests-only dependency (used only by the demo launcher);
  # call it fully qualified so the package does not require Shiny to install.
  shiny::runApp(dir, ...)
  invisible(TRUE)
}
# nocov end
