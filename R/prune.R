# ---- prune(): keep a non-overlapping, hull-covering subset ------------------
#
# `plot3d()` renders whatever radius the object carries: if the streamlines
# hold per-point or per-streamline radius data it draws real 3D tubes at those
# radii, and if they do not it draws thin lines (or tubes at the `radius`
# argument you pass). It never shrinks tubes or hides streamlines on its own:
# if two tubes overlap, that is the tractographer's or the generator's
# business, not rtists's.
#
# `prune()` is the opt-in counterpart to that hands-off philosophy. It is for
# the case where *you*, the user, fabricate fat tubes from streamlines that
# were originally generated as thin lines: with no radius data to lean on you
# pick a single tube `radius`, and `prune()` returns a bundle that keeps as
# many streamlines as possible subject to two constraints:
#
#   1. Non-overlap: any two kept tubes (radius + clearance margin) stay clear
#      of each other.
#   2. Coverage: the kept tubes still cover the whole convex hull of the
#      original bundle, i.e. every point of every streamline sits within
#      `radius` of some kept tube.
#
# The point of the utility is precisely to make sure the overlap was not
# introduced by you when you fattened line-only data into tubes.
#
# Algorithm (greedy, deterministic): repeatedly take the kept streamlines in
# "farthest from the already-kept tubes" order, which spreads the selection
# across the bundle's extent, keep the first one whose tube does not overlap an
# already-kept tube, and stop once every remaining point is within `radius` of
# a kept tube (the hull is covered).

# Distance from point `pt` to the nearest of a set of kept polylines.
.point_to_set <- function(pt, kept) {
  min(vapply(kept, function(B) .point_to_polyline(pt, B), numeric(1L)))
}

# Farthest distance from any point of polyline `A` to a set of kept polylines:
# 0 when A is entirely within `r` of the kept tubes (fully covered), positive
# when A still contributes new ground.
.streamline_cover_gap <- function(A, kept) {
  max(vapply(seq_len(nrow(A)), function(i)
    .point_to_set(A[i, ], kept), numeric(1L)))
}

# Greedy prune over a list of polylines. Returns the integer indices kept.
.prune_indices <- function(polys, radius, overlap_margin = 1, max_iter = Inf) {
  m <- length(polys)
  if (m < 2L) return(seq_len(m))            # nothing to prune
  req <- 2 * radius * overlap_margin        # centre-to-centre clearance needed
  keep <- integer(0)
  remaining <- seq_len(m)
  n_iter <- 0L
  while (length(remaining) > 0L && n_iter < max_iter) {
    n_iter <- n_iter + 1L
    if (length(keep) == 0L) {
      ord <- seq_along(remaining)           # no kept set yet: index order
    } else {
      # Farthest-first over the remaining streamlines relative to kept tubes.
      gap <- vapply(remaining, function(i)
        .streamline_cover_gap(polys[[i]], polys[keep]), numeric(1L))
      ord <- order(-gap, remaining)         # farthest first, index tie-break
    }
    chosen <- NULL
    for (o in ord) {
      i <- remaining[o]
      if (length(keep) == 0L ||
          all(vapply(keep, function(j) .min_sep_two(polys[[i]], polys[[j]]),
                     numeric(1L)) >= req)) {
        chosen <- i
        break
      }
    }
    if (is.null(chosen)) break              # every remaining tube overlaps
    keep <- c(keep, chosen)
    remaining <- setdiff(remaining, chosen)
    # Stop once the kept tubes cover the convex hull: every remaining point is
    # within `radius` of a kept tube.
    if (length(remaining) > 0L) {
      covered <- vapply(remaining, function(i)
        .streamline_cover_gap(polys[[i]], polys[keep]) <= radius, logical(1L))
      if (all(covered)) break
    }
  }
  sort(keep)
}

# ---- S7 generic --------------------------------------------------------------

#' Prune a tractography bundle to non-overlapping, hull-covering tubes
#'
#' @description
#' `prune()` thins a [fiber::bundle] (or a [fiber::bundle_set]) down to a
#' subset of streamlines that can be rendered as fat non-overlapping tubes.
#' Use it when *you* build the tubes yourself, from streamlines that carry no
#' per-point or per-streamline radius: you choose a single tube `radius`, and
#' `prune()` keeps as many streamlines as possible such that:
#'
#' - any two kept tubes (radius plus `overlap_margin` clearance) stay clear of
#'   each other, and
#' - the kept tubes still cover the whole convex hull of the original bundle
#'   (every point lies within `radius` of a kept tube).
#'
#' [plot3d()] never shrinks tubes or drops streamlines on its own; it renders
#' whatever radius the object carries. So `prune()` is the tool to reach for
#' when you fabricate fat tubes from line-only data and want to make sure the
#' overlap was not introduced by you.
#'
#' The selection is greedy and deterministic, preferring streamlines that sit
#' farthest from the already-kept tubes so the retained set spreads across the
#' bundle rather than clustering.
#'
#' @param x A [fiber::bundle] or [fiber::bundle_set] to prune.
#' @param radius Positive number. The tube radius (world units) used both for
#'   the non-overlap clearance and for the hull-coverage test.
#' @param overlap_margin Numeric. Multiplier on the centre-to-centre clearance
#'   between kept tubes. The default `1` keeps tubes exactly at radius so they
#'   just touch; a value above `1` leaves a visible gap (and a value below `1`
#'   would let them interpenetrate, which is allowed but rarely wanted).
#' @param ... Reserved for future arguments.
#'
#' @returns An object of the same class as `x` holding the pruned subset of
#'   streamlines. For a [fiber::bundle_set] the pruning is applied to every
#'   bundle independently, and empty bundles are dropped from the returned set.
#'
#' @seealso [plot3d()]
#' @export
prune <- S7::new_generic(
  name = "prune",
  dispatch_args = "x",
  fun = function(x, radius, overlap_margin = 1, ...) {
    S7::S7_dispatch()
  }
)

# ---- S7 methods --------------------------------------------------------------

#' [prune()] method for `fiber::bundle` objects
#'
#' Prunes a [fiber::bundle] to a non-overlapping subset whose tubes still cover
#' the bundle's convex hull. See [prune()] for the full parameter
#' documentation.
#'
#' @inheritParams prune
#' @returns A [fiber::bundle] holding the pruned subset of streamlines.
#' @seealso [prune()]
#' @name prune-fiber-bundle-method
#' @aliases prune,fiber::bundle-method
#' @usage NULL
#' @examples
#' library(fiber)
#'
#' # Six line-only streamlines in a bundle (no radius data on them). Rendered
#' # as thin lines by default; if you want to draw them as fat tubes you would
#' # pick a radius yourself. At radius 1 the six packed strands overlap.
#' sl  <- streamline(cbind(X = seq_len(200) * 0.1,
#'                         Y = 0.25 * sin(seq_len(200) / 200 * 4 * pi),
#'                         Z = 0.25 * cos(seq_len(200) / 200 * 4 * pi)))
#' strand <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   streamline(cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
#'     Z = 0.25 * cos(t) + (i - 3.5) * 0.15
#'   ))
#' }
#' bun <- bundle(lapply(seq_len(6), strand))
#'
#' # Because the tubes are fabricated by you from line-only data, prune keeps
#' # a spread-out subset whose fat tubes do not overlap: the extreme strands.
#' pruned <- prune(bun, radius = 1)
#' length(pruned@streamlines)
S7::method(prune, fiber::bundle) <- function(
    x,
    radius,
    overlap_margin = 1,
    ...) {
  if (!is.numeric(radius) || length(radius) != 1L || is.na(radius) ||
      radius <= 0) {
    stop("`radius` must be a single positive number.", call. = FALSE)
  }
  if (!is.numeric(overlap_margin) || length(overlap_margin) != 1L ||
      is.na(overlap_margin) || overlap_margin <= 0) {
    stop("`overlap_margin` must be a single positive number.", call. = FALSE)
  }
  polys <- lapply(x@streamlines, function(s) as.matrix(s@points))
  idx <- .prune_indices(polys, radius, overlap_margin)
  fiber::bundle(x@streamlines[idx])
}

#' [prune()] method for `fiber::bundle_set` objects
#'
#' Prunes every [fiber::bundle] in a [fiber::bundle_set] independently and
#' returns a set holding the pruned (non-empty) bundles. See [prune()] for the
#' full parameter documentation.
#'
#' @inheritParams prune
#' @returns A [fiber::bundle_set] holding the pruned bundles; bundles pruned
#'   down to zero streamlines are dropped.
#' @seealso [prune()]
#' @name prune-fiber-bundle_set-method
#' @aliases prune,fiber::bundle_set-method
#' @usage NULL
S7::method(prune, fiber::bundle_set) <- function(
    x,
    radius,
    overlap_margin = 1,
    ...) {
  pruned <- lapply(x@bundles, function(b) prune(b, radius, overlap_margin))
  pruned <- Filter(function(b) length(b@streamlines) > 0L, pruned)
  fiber::bundle_set(pruned)
}
