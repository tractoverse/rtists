# Availability helper: wraps requireNamespace() so tests can mock the check
# via mockthat without touching R's locked base namespace. The plotly backend
# (Suggests) is detected through this function (see .plot3d_impl()).
is_installed <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}
