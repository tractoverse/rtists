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

# three.js tube mode (radius > 0) carries the tube payload
fig <- plot3d(sl, radius = 0.25)
expect_true(all(c("tubeOffsets", "radii") %in% names(fig$x)))

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

# scalar radius > 0 -> true 3D tube: per-point constant radii + tubeOffsets,
# no `thickness` echo
fig <- plot3d(sl, radius = 0.25)
expect_equal(unclass(fig$x$mode), "tube")
# radii are per-point floats packed as IEEE float32 -> 4 raw bytes/float
expect_true(is.raw(fig$x$positions))
expect_equal(length(fig$x$positions), 12L * nrow(pts))  # 3 floats x 4 bytes/point
expect_true(is.raw(fig$x$radii))
expect_equal(length(fig$x$radii), 4L * nrow(pts))
expect_true(!("thickness" %in% names(fig$x)))
expect_equal(fig$x$tubeOffsets, c(0L, nrow(pts)))
expect_true(is.null(fig$x$linewidth) || fig$x$linewidth > 0)

# scalar radius == 0 -> fast flat Line2 world width, radii dropped
fig <- plot3d(sl, radius = 0)
expect_equal(unclass(fig$x$mode), "line2")
expect_true(fig$x$linewidth > 0)
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

# ---- radius carried on the streamline objects (3js) -------------------------
# rtists relies on a `radius` key the generator stored in @point_data (per
# point) or @streamline_data (per streamline) whenever the caller does not pass
# an explicit `radius`. See the @radius doc on plot3d().

# per-streamline radius in @streamline_data -> one tube radius per fibre.
bun_r <- fiber::bundle(list(
  fiber::streamline(pts, streamline_data = list(radius = 0.2)),
  fiber::streamline(pts + 1, streamline_data = list(radius = 0.8))
))
fig <- plot3d(bun_r)
expect_equal(unclass(fig$x$mode), "tube")
radii <- readBin(fig$x$radii, numeric(), size = 4L,
                 n = length(fig$x$radii) / 4L)
expect_equal(radii, rep(c(0.2, 0.8), each = nrow(pts)), tolerance = 1e-6)

# per-point radius in @point_data -> radius varying along the fibre.
sl_pp <- fiber::streamline(pts, point_data = list(radius = seq(0.1, 0.5, 0.1)))
fig <- plot3d(sl_pp)
expect_equal(unclass(fig$x$mode), "tube")
expect_equal(readBin(fig$x$radii, numeric(), size = 4L, n = nrow(pts)),
             seq(0.1, 0.5, 0.1), tolerance = 1e-6)

# an explicit `radius` argument overrides any radius stored on the object.
fig <- plot3d(bun_r, radius = 0.05)
expect_equal(unclass(fig$x$mode), "tube")
radii <- readBin(fig$x$radii, numeric(), size = 4L,
                 n = length(fig$x$radii) / 4L)
expect_equal(unique(round(radii, 5)), 0.05)

# no radius anywhere and no argument -> fast thin Line2.
fig <- plot3d(sl)
expect_equal(unclass(fig$x$mode), "line2")
expect_true(is.null(fig$x$radii))

# rtists does NOT police overlap at render time: fat tubes on coincident
# streamlines keep the requested radius (overlap is the generator's concern;
# use prune() only when you fabricate tubes yourself from line-only data).
bs_same <- fiber::bundle_set(list(
  fiber::bundle(list(sl)),
  fiber::bundle(list(sl))
))
fig <- plot3d(bs_same, radius = 0.08)
expect_equal(unclass(fig$x$mode), "tube")
radii <- readBin(fig$x$radii, numeric(), size = 4L,
                 n = length(fig$x$radii) / 4L)
expect_true(all(abs(radii - 0.08) < 1e-5))   # requested radius left untouched

# ---- mixed-metadata bundle sets (CST/SLF/CC style) ---------------------------

# A bundle_set whose bundles carry different metadata columns must still fold
# into one dataframe: the CST bundle carries a `radius` key while the CC and
# SLF bundles carry none. `.bundle_set_to_df()` aligns the parts to the union
# of their columns (missing -> NA) instead of failing on an rbind mismatch.
sl_no_meta <- fiber::streamline(
  points = matrix(
    c(1, 0, 0, 2, 0, 0, 3, 0, 0), ncol = 3, byrow = TRUE,
    dimnames = list(NULL, c("X", "Y", "Z"))
  )
)
sl_radius <- fiber::streamline(
  points = matrix(
    c(0, 1, 0, 0, 2, 0), ncol = 3, byrow = TRUE,
    dimnames = list(NULL, c("X", "Y", "Z"))
  ),
  streamline_data = list(radius = 0.1)
)
bun_rad <- fiber::bundle(list(sl_radius, sl_radius))
bun_plain <- fiber::bundle(list(sl_no_meta))
bs_mixed <- fiber::bundle_set(list(CST = bun_rad, CC = bun_plain))

mdf <- rtists:::.bundle_set_to_df(bs_mixed)
expect_inherits(mdf, "data.frame")
expect_true("radius" %in% names(mdf))            # union carries the radius column
# only the CST streamlines actually hold a radius; the CC ones are NA
expect_equal(sort(unique(mdf$BundleName)), c("CC", "CST"))
expect_true(all(is.na(mdf$radius[mdf$BundleName == "CC"])))
expect_true(all(mdf$radius[mdf$BundleName == "CST"] == 0.1))

# plot3d on the mixed set draws a widget without erroring.
fig <- suppressMessages(plot3d(bs_mixed))
expect_inherits(fig, "rtists")
cat("mixed-metadata bundle_set tests OK\n")
