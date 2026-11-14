# ---- fatten() ---------------------------------------------------------------
#
# fatten() assigns a visible tube radius to line-only streamline objects so a
# subsequent plot3d() call draws real 3D tubes. Sparse bundles keep all fibres
# at half the minimal separation; dense bundles prune to a non-overlapping
# subset at the visibility floor (the median sampling step, or the user
# override).

strand <- function(i) {
  t <- seq(0, 4 * pi, length.out = 200)
  fiber::streamline(cbind(
    X = seq_len(200) * 0.1,
    Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
    Z = 0.25 * cos(t) + (i - 3.5) * 0.15
  ))
}
pack <- function(i) {
  t <- seq(0, 4 * pi, length.out = 100)
  fiber::streamline(cbind(
    X = seq_len(100) * 0.5,
    Y = 0.5 + (i - 3.5) * 0.3,
    Z = 0.25 * sin(t) + (i - 3.5) * 0.05
  ))
}
bun_sparse <- fiber::bundle(lapply(seq_len(6), strand))
bun_dense  <- fiber::bundle(lapply(seq_len(6), pack))

polys_sparse <- lapply(bun_sparse@streamlines, function(s) as.matrix(s@points))
polys_dense  <- lapply(bun_dense@streamlines, function(s) as.matrix(s@points))
floor_dense  <- rtists:::.fatten_step(polys_dense)   # median sampling step

# ---- sparse bundle: keep all at half the minimal separation ----------------

fs <- fatten(bun_sparse)
expect_inherits(fs, "fiber::bundle")
expect_equal(length(fs@streamlines), 6L)          # sparse: nothing pruned
r_sp <- fs@streamline_data$radius
expect_length(r_sp, 6L)
# per-streamline radius equals half the minimal inter-streamline separation
dmin <- Inf
for (a in 1:5) for (b in (a + 1):6)
  dmin <- min(dmin, rtists:::.min_sep_two(polys_sparse[[a]], polys_sparse[[b]]))
expect_equal(unique(r_sp), dmin / 2)
expect_true(all(r_sp > 0))
expect_equal(dmin, rtists:::.fatten_dmin(polys_sparse))
# the sparse radius is above the visibility floor (that is why nothing prunes)
expect_true(dmin / 2 >= rtists:::.fatten_step(polys_sparse))

# tubes at this radius are non-overlapping: every pair is >= 2 * radius apart
ok <- TRUE
for (a in seq_along(fs@streamlines))
  for (b in seq_along(fs@streamlines))
    if (a < b &&
        rtists:::.min_sep_two(as.matrix(fs@streamlines[[a]]@points),
                              as.matrix(fs@streamlines[[b]]@points)) < 2 * r_sp[1])
      ok <- FALSE
expect_true(ok)

# the fattened bundle renders as real 3D tubes via plot3d (the API contract)
fig <- plot3d(fs)
expect_inherits(fig, "rtists")
expect_equal(unclass(fig$x$mode), "tube")

# ---- dense bundle: prune to extremes at the visibility floor ---------------

fd <- fatten(bun_dense)
expect_inherits(fd, "fiber::bundle")
# dense packing prunes; the pack strands cluster so only extremes survive
expect_true(length(fd@streamlines) < 6L)
r_dn <- fd@streamline_data$radius
expect_length(r_dn, length(fd@streamlines))
# dense tubes sit at the visibility floor, the median sampling step
expect_equal(unique(r_dn), floor_dense)
# the pruned subset matches .prune_indices at the floor radius
expect_equal(length(fd@streamlines),
             length(rtists:::.prune_indices(polys_dense, floor_dense, 1)))
# and plot3d still renders tubes
fig <- plot3d(fd)
expect_equal(unclass(fig$x$mode), "tube")

# ---- single streamline: gets the visibility floor, nothing to prune --------

fo <- fatten(bun_dense@streamlines[[1]])
expect_inherits(fo, "fiber::streamline")
# a lone fibre has no neighbours: radius = visibility floor (median step)
expect_equal(fo@streamline_data$radius,
             rtists:::.fatten_step(list(as.matrix(bun_dense@streamlines[[1]]@points))))

# ---- visibility override ----------------------------------------------------

# a large override floors the radius at the user's value for a dense bundle
fdv <- fatten(bun_dense, visibility = 1.0)
expect_equal(unique(fdv@streamline_data$radius), 1.0)
expect_true(length(fdv@streamlines) < 6L)         # still pruned at the larger size

# a small override pushes the floor below the separation: sparse keep-all
fsv <- fatten(bun_dense, visibility = 0.05)
expect_equal(length(fsv@streamlines), 6L)         # sparse branch: keep all
expect_equal(unique(fsv@streamline_data$radius), rtists:::.fatten_dmin(polys_dense) / 2)

# ---- validation -------------------------------------------------------------

expect_error(fatten(bun_sparse, visibility = -1), "single positive number")
expect_error(fatten(bun_sparse, visibility = "a"), "single positive number")
expect_error(fatten(bun_sparse, visibility = NA_real_), "single positive number")

# ---- empty bundle -----------------------------------------------------------

fe <- fatten(fiber::bundle(list()))
expect_inherits(fe, "fiber::bundle")
expect_equal(length(fe@streamlines), 0L)

# ---- bundle_set: fatten each bundle independently ---------------------------

cs <- fiber::bundle_set(list(fan = bun_sparse, pack = bun_dense))
fcs <- fatten(cs)
expect_inherits(fcs, "fiber::bundle_set")
expect_equal(length(fcs@bundles), 2L)
expect_equal(vapply(fcs@bundles, function(b) length(b@streamlines), integer(1)),
             c(6L, length(fd@streamlines)))
expect_equal(unique(fcs@bundles[[1]]@streamline_data$radius),
             unique(fs@streamline_data$radius))
expect_equal(unique(fcs@bundles[[2]]@streamline_data$radius), floor_dense)
fig <- plot3d(fcs)
expect_equal(unclass(fig$x$mode), "tube")

# an empty bundle *inside* a set is dropped by the set-level fatten
cs_empty <- fiber::bundle_set(list(keep = bun_sparse, gone = fiber::bundle(list())))
fce <- fatten(cs_empty)
expect_equal(length(fce@bundles), 1L)
expect_equal(fce@bundles[[1]]@streamline_data$radius, fs@streamline_data$radius)
