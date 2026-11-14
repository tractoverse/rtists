# ---- shared polyline geometry helpers ----------------------------------------
#
# Small distance/geometry utilities shared by the tube backend and the prune
# routine. Kept here so identical code is not defined twice.

# Minimum distance from point `pt` to any segment of polyline `B` (3-column).
.point_to_polyline <- function(pt, B) {
  # endpoints + direction of each segment of B
  s <- B[-nrow(B), , drop = FALSE]
  e <- B[-1L, , drop = FALSE]
  d1 <- e - s
  len2 <- rowSums(d1^2)
  # project pt onto each infinite line, clamp to [0, 1]
  t <- ((pt[1] - s[, 1]) * d1[, 1] +
        (pt[2] - s[, 2]) * d1[, 2] +
        (pt[3] - s[, 3]) * d1[, 3]) / len2
  t <- pmax(0, pmin(1, t))
  q <- s + t * d1
  min(sqrt(rowSums((q - matrix(pt, nrow = nrow(q), ncol = 3, byrow = TRUE))^2)))
}

# Minimum separation (closest approach) between two streamlines: minimum over
# every point of A to the polyline B and every point of B to the polyline A.
.min_sep_two <- function(A, B) {
  dAB <- min(vapply(seq_len(nrow(A)), function(i) .point_to_polyline(A[i, ], B),
                    numeric(1L)))
  dBA <- min(vapply(seq_len(nrow(B)), function(i) .point_to_polyline(B[i, ], A),
                    numeric(1L)))
  min(dAB, dBA)
}
