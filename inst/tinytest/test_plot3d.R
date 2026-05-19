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

fig <- plot3d(sl)
expect_inherits(fig, "plotly")

fig <- plot3d(bun)
expect_inherits(fig, "plotly")

# ---- plot3d: colour modes ----------------------------------------------------

plot3d(sl)
plot3d(sl, color = "FA")
plot3d(bun, color = "mean_FA")
plot3d(sl, color = "steelblue")
plot3d(sl, color = "#E69F00")