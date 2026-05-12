pts <- matrix(
  c(0, 0, 0,
    1, 1, 0,
    2, 1, 1,
    3, 2, 2,
    4, 3, 2),
  ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)
sl <- riot::new_streamline(
  points          = pts,
  point_data      = list(FA = c(0.3, 0.5, 0.7, 0.6, 0.4)),
  streamline_data = list(mean_FA = 0.5)
)
bun <- riot::new_bundle(list(sl, sl))

# ---- .streamline_to_df ------------------------------------------------------

test_that(".streamline_to_df returns a correctly shaped data frame", {
  df <- rtists:::.streamline_to_df(sl)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 5L)
  expect_true(all(c("StreamlineId", "PointId", "X", "Y", "Z") %in% names(df)))
  expect_true(all(c("FA", "mean_FA") %in% names(df)))
  expect_equal(df$StreamlineId, rep(1L, 5L))
  expect_equal(df$PointId, 1:5)
})

test_that(".streamline_to_df respects streamline_id argument", {
  df <- rtists:::.streamline_to_df(sl, streamline_id = 7L)
  expect_equal(unique(df$StreamlineId), 7L)
})

# ---- .bundle_to_df ----------------------------------------------------------

test_that(".bundle_to_df stacks streamlines correctly", {
  df <- rtists:::.bundle_to_df(bun)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 10L)
  expect_equal(sort(unique(df$StreamlineId)), 1:2)
  expect_true("mean_FA" %in% names(df))
})

# ---- plot3d: return type -----------------------------------------------------

test_that("plot3d returns a plotly object for a streamline", {
  fig <- plot3d(sl)
  expect_s3_class(fig, "plotly")
})

test_that("plot3d returns a plotly object for a bundle", {
  fig <- plot3d(bun)
  expect_s3_class(fig, "plotly")
})

# ---- plot3d: colour modes ----------------------------------------------------

test_that("plot3d works with orientation colouring (default)", {
  expect_no_error(plot3d(sl))
})

test_that("plot3d works with a numeric point_data key", {
  expect_no_error(plot3d(sl, color = "FA"))
})

test_that("plot3d works with a numeric streamline_data key on a bundle", {
  expect_no_error(plot3d(bun, color = "mean_FA"))
})

test_that("plot3d works with a fixed CSS colour string", {
  expect_no_error(plot3d(sl, color = "steelblue"))
})

test_that("plot3d works with a hex colour string", {
  expect_no_error(plot3d(sl, color = "#E69F00"))
})
