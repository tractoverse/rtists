# ---- prune() -----------------------------------------------------------------

strand <- function(i) {
  t <- seq(0, 4 * pi, length.out = 200)
  fiber::streamline(cbind(
    X = seq_len(200) * 0.1,
    Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
    Z = 0.25 * cos(t) + (i - 3.5) * 0.15
  ))
}
bun6 <- fiber::bundle(lapply(seq_len(6), strand))
polys <- lapply(bun6@streamlines, function(s) as.matrix(s@points))

# ---- .prune_indices ----------------------------------------------------------

# Nothing to prune with fewer than two streamlines.
expect_identical(rtists:::.prune_indices(list(polys[[1]]), 0.5), 1L)
expect_identical(rtists:::.prune_indices(list(), 0.5), integer(0))

# All six strands fit below the nearest-neighbour separation (0.9): 2*0.3=0.6.
expect_identical(rtists:::.prune_indices(polys, 0.3), 1:6)

# At radius 1.0 only strands >= 2 apart survive; farthest-first spreads them to
# the bundle extremes {1, 6}.
expect_identical(rtists:::.prune_indices(polys, 1.0), c(1L, 6L))

# Keeping the non-overlap invariant: every pair of kept tubes is >= 2*radius.
check <- function(indices, radius) {
  if (length(indices) < 2L) return(TRUE)
  for (a in seq_along(indices))
    for (b in seq_along(indices))
      if (a < b &&
          rtists:::.min_sep_two(polys[[indices[a]]], polys[[indices[b]]]) < 2 * radius)
        return(FALSE)
  TRUE
}
expect_true(check(rtists:::.prune_indices(polys, 0.6), 0.6))
expect_true(check(rtists:::.prune_indices(polys, 0.9), 0.9))
expect_true(check(rtists:::.prune_indices(polys, 1.5), 1.5))

# ---- prune(), bundle ---------------------------------------------------------

# Returns a fiber bundle of the pruned subset.
pr <- prune(bun6, radius = 0.3)
expect_inherits(pr, "fiber::bundle")
expect_equal(length(pr@streamlines), 6L)

pr <- prune(bun6, radius = 1.0)
expect_equal(length(pr@streamlines), 2L)
# The two kept strands are the bundle's extremes (widest lateral spacing).
expect_true(check(vapply(pr@streamlines, function(s) {
  which(vapply(polys, function(p) isTRUE(all.equal(as.matrix(s@points), p)),
               logical(1)))
}, integer(1)), 1.0))

# Single-streamline bundle is returned unchanged.
one <- fiber::bundle(list(fiber::streamline(polys[[1]])))
expect_equal(length(prune(one, radius = 2.0)@streamlines), 1L)

# ---- prune(), bundle_set -----------------------------------------------------

# Each bundle is pruned independently.
bs <- fiber::bundle_set(list(bun6, bun6))
prs <- prune(bs, radius = 1.0)
expect_inherits(prs, "fiber::bundle_set")
expect_equal(length(prs@bundles), 2L)
expect_equal(vapply(prs@bundles, function(b) length(b@streamlines), integer(1)),
             c(2L, 2L))

# ---- validation --------------------------------------------------------------

expect_error(prune(bun6, radius = -1), "`radius` must be a single positive number")
expect_error(prune(bun6, radius = "a"), "`radius` must be a single positive number")
expect_error(prune(bun6, radius = 1, overlap_margin = -1),
             "`overlap_margin` must be a single positive number")
expect_error(prune(bun6, radius = 1, overlap_margin = "a"),
             "`overlap_margin` must be a single positive number")
