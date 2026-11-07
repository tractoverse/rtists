# ---- fatten(): give line-only streamlines a visible tube radius --------------
#
# `plot3d()` renders whatever radius the object carries: streamlines without a
# radius draw as thin lines, and streamlines with a per-point or per-streamline
# radius draw as real 3D tubes. `fatten()` is the companion to `prune()` that
# *assigns* that radius. Given a streamline, bundle or bundle_set that carries
# no radius data, it derives a radius guaranteed to be visible to the naked eye
# and stores it back on the object as a per-streamline `radius` key, so a plain
# `plot3d()` then draws real 3D tubes with no `radius` argument needed.
#
# Two regimes, decided by how packed the streamlines are:
#
#   * Sparse. When the closest approach between any two streamlines is large
#     enough that a provably non-overlapping tube is still visible, the assigned
#     radius is that half-separation; tubes just touch and nothing is hidden.
#   * Dense. When the streamlines sit closer together than the visibility floor,
#     `fatten()` prunes to a non-overlapping, hull-covering subset at that floor
#     radius (the minimal visible size, which preserves the most streamlines).
#
# Visibility floor: a tube is considered visible when its radius is at least the
# median distance between consecutive sampled points of the streamlines (the
# sampling density). Callers may override the floor with `visibility`.

# Median intra-streamline sampling step: the typical distance between
# consecutive points along the fibres. A stream sampling every 1 mm yields a
# floor near 1 mm, the smallest tube radius considered visible here.
.fatten_step <- function(polys) {
  steps <- unlist(lapply(polys, function(P) {
    d <- P[-1, , drop = FALSE] - P[-nrow(P), , drop = FALSE]
    sqrt(rowSums(d^2))
  }), use.names = FALSE)
  stats::median(steps)
}

# Minimal distance between any two streamlines across the whole bundle (closest
# approach). Inf when there are fewer than two, so the sparse branch is skipped.
.fatten_dmin <- function(polys) {
  if (length(polys) < 2L) return(Inf)
  m <- length(polys)
  dmin <- Inf
  for (a in seq_len(m - 1L))
    for (b in (a + 1L):m)
      dmin <- min(dmin, .min_sep_two(polys[[a]], polys[[b]]))
  dmin
}

# Attach a constant per-streamline `radius` to one streamline, preserving its
# existing point and streamline data.
.fatten_sl <- function(s, r) {
  sd <- s@streamline_data
  sd$radius <- r
  fiber::streamline(
    points          = s@points,
    point_data      = s@point_data,
    streamline_data = sd
  )
}

# Resolve the visibility floor from the user override or the median step.
.fatten_floor <- function(polys, visibility) {
  if (!is.null(visibility)) {
    if (!is.numeric(visibility) || length(visibility) != 1L ||
        is.na(visibility) || visibility <= 0) {
      stop("`visibility` must be a single positive number (or NULL).",
           call. = FALSE)
    }
    return(visibility)
  }
  .fatten_step(polys)
}

# ---- S7 generic --------------------------------------------------------------

#' Assign a visible tube radius to line-only streamlines
#'
#' @description
#' `fatten()` gives a [fiber::streamline], [fiber::bundle], or
#' [fiber::bundle_set] that carries no radius data a tube radius guaranteed to
#' be visible to the naked eye, and stores it back on the object as a
#' per-streamline `radius` key. Where [plot3d()] *reports* radius data the object
#' already carries, and [prune()] thins a bundle down to a non-overlapping
#' subset at a radius you choose, over which [prune()] gives you full control
#' as the tunable engine. `fatten()` is the convenience wrapper that *picks* a
#' radius for you and then reuses [prune()]'s selection logic internally for
#' the dense case: afterwards a plain `plot3d()` call draws real 3D tubes.
#' When you would rather pick the radius and the clearance between tubes
#' yourself, call [prune()] directly instead.
#'
#' The radius is chosen from the geometry of the streamlines themselves:
#'
#' - **Sparse** streamlines (far apart relative to the visibility floor) keep
#'   all their fibres and get a constant radius equal to half the minimal
#'   distance between any two streamlines, so adjacent tubes just touch and
#'   nothing is hidden.
#' - **Dense** streamlines (packed closer than the floor) are pruned to a
#'   non-overlapping, hull-covering subset at the floor radius, preserving as
#'   many streamlines as can be shown without overlap at a visible size.
#'
#' The visibility floor is the median distance between consecutive sampled
#' points of the streamlines (the sampling density); a tube is treated as
#' visible once its radius reaches that spacing. Override it with `visibility`.
#'
#' @param x A [fiber::streamline], [fiber::bundle], or [fiber::bundle_set].
#' @param visibility Numeric. The smallest tube radius considered visible to the
#'   naked eye. `NULL` (default) derives it from the streamlines' sampling
#'   density (the median intra-streamline step); a positive number overrides the
#'   floor.
#' @param ... Reserved for future arguments.
#'
#' @returns An object of the same class as `x` in which every streamline carries
#'   a per-streamline `radius` in its `@streamline_data`, so a subsequent
#'   [plot3d()] call renders real 3D tubes. For a dense [fiber::bundle] or
#'   [fiber::bundle_set], the returned object holds the pruned (non-overlapping)
#'   subset of streamlines.
#'
#' @seealso [prune()], [plot3d()]
#' @export
fatten <- S7::new_generic(
  name = "fatten",
  dispatch_args = "x",
  fun = function(x, visibility = NULL, ...) {
    S7::S7_dispatch()
  }
)

# ---- S7 methods --------------------------------------------------------------

#' [fatten()] method for `fiber::streamline` objects
#'
#' Assigns a single [fiber::streamline] a visible tube radius (the visibility
#' floor) so [plot3d()] draws it as a real 3D tube. A lone fibre has no other
#' streamlines to collide with, so there is nothing to prune.
#'
#' @inheritParams fatten
#' @returns A [fiber::streamline] carrying a per-streamline `radius`.
#' @seealso [fatten()]
#' @name fatten-fiber-streamline-method
#' @aliases fatten,fiber::streamline-method
#' @usage NULL
#' @examples
#' library(fiber)
#'
#' # A smooth fibre curving through 3-D space, sampled at a 0.1 mm step.
#' t   <- seq(0, 4 * pi, length.out = 200)
#' sl <- streamline(cbind(
#'   X = seq_len(200) * 0.1,
#'   Y = 0.5 * sin(t),
#'   Z = 0.5 * cos(t)
#' ))
#'
#' # fatten() attaches a per-streamline radius; plot3d() then draws a tube.
#' fattened <- fatten(sl)
#' fattened@streamline_data$radius
#' plot3d(fattened)
S7::method(fatten, fiber::streamline) <- function(
    x,
    visibility = NULL,
    ...) {
  f <- .fatten_floor(list(as.matrix(x@points)), visibility)
  .fatten_sl(x, f)
}

#' [fatten()] method for `fiber::bundle` objects
#'
#' Assigns a visible tube radius to every [fiber::streamline] in a
#' [fiber::bundle]. When the streamlines are sparse the whole bundle is kept at
#' a radius of half the minimal inter-streamline separation; when they are dense
#' the bundle is pruned to a non-overlapping, hull-covering subset at the
#' visibility floor. See [fatten()] for the full parameter documentation.
#'
#' @inheritParams fatten
#' @returns A [fiber::bundle] in which every streamline carries a per-streamline
#'   `radius`; dense bundles hold the pruned subset of streamlines.
#' @seealso [fatten()]
#' @name fatten-fiber-bundle-method
#' @aliases fatten,fiber::bundle-method
#' @usage NULL
#' @examples
#' library(fiber)
#'
#' # Six line-only streamlines: six helix strands fanning apart in the lateral
#' # (Y) direction, each sampled at a 0.1 mm step. They are far enough apart
#' # that a visible tube radius keeps them from colliding: the sparse regime.
#' strand <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   fiber::streamline(cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
#'     Z = 0.25 * cos(t) + (i - 3.5) * 0.15
#'   ))
#' }
#' bun <- fiber::bundle(lapply(seq_len(6), strand))
#'
#' # Every streamline now carries a per-streamline radius, and all six survive.
#' fattened <- fatten(bun)
#' length(fattened@streamlines)
#' plot3d(fattened)              # draws real 3D tubes
S7::method(fatten, fiber::bundle) <- function(
    x,
    visibility = NULL,
    ...) {
  polys <- lapply(x@streamlines, function(s) as.matrix(s@points))
  if (length(polys) == 0L) return(fiber::bundle(list()))
  f    <- .fatten_floor(polys, visibility)
  dmin <- .fatten_dmin(polys)
  if (dmin / 2 >= f) {
    # Sparse: tubes at half the minimal separation just touch; keep all fibres.
    r    <- dmin / 2
    kept <- x@streamlines
  } else {
    # Dense: prune to a non-overlapping, hull-covering subset at the floor.
    r    <- f
    kept <- x@streamlines[.prune_indices(polys, f, 1)]
  }
  # fiber::bundle() hoists any per-streamline metadata to the bundle level as
  # one vector per streamline, so the radius must be handed to the constructor's
  # `streamline_data` argument (a per-streamline vector) rather than attached to
  # the nested streamlines, which bundle() would strip.
  fiber::bundle(kept, streamline_data = list(radius = rep(r, length(kept))))
}

#' [fatten()] method for `fiber::bundle_set` objects
#'
#' Fatens every [fiber::bundle] in a [fiber::bundle_set] independently, each
#' with its own visibility floor and pruning decision, and returns a set of the
#' resulting bundles. See [fatten()] for the full parameter documentation.
#'
#' @inheritParams fatten
#' @returns A [fiber::bundle_set] in which every streamline carries a
#'   per-streamline `radius`; dense bundles hold their pruned subset, and
#'   bundles pruned down to zero streamlines are dropped.
#' @seealso [fatten()]
#' @name fatten-fiber-bundle_set-method
#' @aliases fatten,fiber::bundle_set-method
#' @usage NULL
#' @examples
#' library(fiber)
#'
#' # Two bundles of line-only streamlines in one set: a sparse fanning tract and
#' # a densely packed one. Each is fattened independently.
#' fan <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   fiber::streamline(cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = 0.25 * sin(t) + (i - 3.5) * 1.5,
#'     Z = 0.25 * cos(t)
#'   ))
#' }
#' pack <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 100)
#'   fiber::streamline(cbind(
#'     X = seq_len(100) * 0.5,
#'     Y = 0.5 + (i - 3.5) * 0.3,
#'     Z = 0.25 * sin(t) + (i - 3.5) * 0.05
#'   ))
#' }
#' cs <- fiber::bundle_set(list(
#'   fan  = fiber::bundle(lapply(seq_len(6), fan)),
#'   pack = fiber::bundle(lapply(seq_len(6), pack))
#' ))
#'
#' fattened <- fatten(cs)
#' vapply(fattened@bundles, function(b) length(b@streamlines), integer(1L))
#' plot3d(fattened)              # draws real 3D tubes per bundle
S7::method(fatten, fiber::bundle_set) <- function(
    x,
    visibility = NULL,
    ...) {
  kept <- lapply(x@bundles, function(b) fatten(b, visibility = visibility))
  kept <- Filter(function(b) length(b@streamlines) > 0L, kept)
  fiber::bundle_set(kept)
}
