pts <- matrix(
  c(0, 0, 0,
    1, 1, 0,
    2, 1, 1,
    3, 2, 2,
    4, 3, 2),
  ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)
sl <- fiber::streamline(
  points          = pts,
  point_data      = list(FA = c(0.3, 0.5, 0.7, 0.6, 0.4)),
  streamline_data = list(mean_FA = 0.5)
)
bun <- fiber::bundle(list(sl, sl))

# ---- .streamline_to_df ------------------------------------------------------

df <- rtists:::.streamline_to_df(sl)
expect_inherits(df, "data.frame")
expect_equal(nrow(df), 5L)
expect_true(all(c("StreamlineId", "PointId", "X", "Y", "Z") %in% names(df)))
expect_true(all(c("FA", "mean_FA") %in% names(df)))
expect_equal(df$StreamlineId, rep(1L, 5L))
expect_equal(df$PointId, 1:5)

df <- rtists:::.streamline_to_df(sl, streamline_id = 7L)
expect_equal(unique(df$StreamlineId), 7L)

# ---- .bundle_to_df ----------------------------------------------------------

df <- rtists:::.bundle_to_df(bun)
expect_inherits(df, "data.frame")
expect_equal(nrow(df), 10L)
expect_equal(sort(unique(df$StreamlineId)), 1:2)
expect_true("mean_FA" %in% names(df))

# ---- plot3d: return type -----------------------------------------------------

# three.js is the default backend
fig <- plot3d(sl)
expect_inherits(fig, "rtists")
fig <- plot3d(bun)
expect_inherits(fig, "rtists")

# plotly backend is selected explicitly. plotly is a Suggests-only
# dependency, so skip these assertions on platforms that do not carry it
# (e.g. some R-hub containers); the plotly-not-installed error branch itself
# is exercised by test_coverage.R via a mocked is_installed().
if (requireNamespace("plotly", quietly = TRUE)) {
  fig <- plot3d(sl, backend = "plotly")
  expect_inherits(fig, "plotly")
  fig <- plot3d(bun, backend = "plotly")
  expect_inherits(fig, "plotly")
}

# three.js tube mode (thickness > 0) carries the tube payload
fig <- plot3d(sl, thickness = 0.25)
expect_true(all(c("tubeOffsets", "thickness") %in% names(fig$x)))

# ---- plot3d: colour modes ----------------------------------------------------

plot3d(sl)
plot3d(sl, color = "FA")
plot3d(bun, color = "mean_FA")
plot3d(sl, color = "steelblue")
plot3d(sl, color = "#E69F00")

# ---- three.js payload: mode / radii / linewidth branches ---------------------

# default -> line2: interleaved segments (6 floats/seg) + rgb (6/seg), no tube
fig <- plot3d(sl)
expect_equal(unclass(fig$x$mode), "line2")
# positions are 6 floats/segment packed as IEEE float32 -> 24 raw bytes/segment
expect_true(is.raw(fig$x$positions))
expect_equal(length(fig$x$positions), 24L * (nrow(pts) - 1L))
# colors are 6 uint8/segment (start rgb + end rgb, 0-255) -> raw bytes
expect_true(is.raw(fig$x$colors))
expect_equal(length(fig$x$colors), 6L * (nrow(pts) - 1L))
expect_true(is.null(fig$x$tubeOffsets))
expect_true(is.null(fig$x$radii))
expect_true(fig$x$linewidth > 0)

# legacy thickness -> tube: per-point radii + tubeOffsets + thickness echo
fig <- plot3d(sl, thickness = 0.25)
expect_equal(unclass(fig$x$mode), "tube")
# radii are per-point floats packed as IEEE float32 -> 4 raw bytes/float
expect_true(is.raw(fig$x$positions))
expect_equal(length(fig$x$positions), 12L * nrow(pts))  # 3 floats x 4 bytes/point
expect_true(is.raw(fig$x$radii))
expect_equal(length(fig$x$radii), 4L * nrow(pts))
expect_equal(unclass(fig$x$thickness), 0.25)
expect_equal(fig$x$tubeOffsets, c(0L, nrow(pts)))
expect_true(is.null(fig$x$linewidth) || fig$x$linewidth > 0)

# scalar radius -> line2 world width (fast path), radii dropped
fig <- plot3d(sl, radius = 0.5)
expect_equal(unclass(fig$x$mode), "line2")
expect_equal(unclass(fig$x$linewidth), 0.5)
expect_true(is.null(fig$x$radii))

# per-streamline radius -> tube (variable per streamline)
fig <- plot3d(bun, radius = c(0.2, 0.8))
expect_equal(unclass(fig$x$mode), "tube")
expect_true(is.raw(fig$x$radii))
expect_length(fig$x$radii, 4L * nrow(pts) * 2L)
expect_equal(fig$x$tubeOffsets, c(0L, nrow(pts), 2L * nrow(pts)))

# per-point radius -> tube, radii equal to that vector
fig <- plot3d(sl, radius = c(0.1, 0.2, 0.3, 0.4, 0.5))
expect_equal(unclass(fig$x$mode), "tube")
expect_true(is.raw(fig$x$radii))
expect_equal(
  readBin(fig$x$radii, numeric(), size = 4L, n = 5L),
  c(0.1, 0.2, 0.3, 0.4, 0.5),
  tolerance = 1e-6
)

# invalid radius forms are rejected
expect_error(plot3d(sl, radius = c(0.1, 0.2)), "radius")