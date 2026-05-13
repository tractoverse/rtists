#' @importFrom cli cli_alert_info
#' @importFrom fiber streamline bundle
NULL

.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
