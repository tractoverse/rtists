# [`prune()`](https://tractoverse.github.io/rtists/reference/prune.md) method for `fiber::bundle` objects

Prunes a
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
to a non-overlapping subset whose tubes still cover the bundle's convex
hull. See
[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md) for
the full parameter documentation.

## Arguments

- x:

  A
  [fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
  or
  [fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  to prune.

- radius:

  Positive number. The tube radius (world units) used both for the
  non-overlap clearance and for the hull-coverage test.

- overlap_margin:

  Numeric. Multiplier on the centre-to-centre clearance between kept
  tubes. The default `1` keeps tubes exactly at radius so they just
  touch; a value above `1` leaves a visible gap (and a value below `1`
  would let them interpenetrate, which is allowed but rarely wanted).

- ...:

  Reserved for future arguments.

## Value

A
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
holding the pruned subset of streamlines.

## See also

[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md)

## Examples

``` r
library(fiber)

# Six line-only streamlines in a bundle (no radius data on them). Rendered
# as thin lines by default; if you want to draw them as fat tubes you would
# pick a radius yourself. At radius 1 the six packed strands overlap.
sl  <- streamline(cbind(X = seq_len(200) * 0.1,
                        Y = 0.25 * sin(seq_len(200) / 200 * 4 * pi),
                        Z = 0.25 * cos(seq_len(200) / 200 * 4 * pi)))
strand <- function(i) {
  t <- seq(0, 4 * pi, length.out = 200)
  streamline(cbind(
    X = seq_len(200) * 0.1,
    Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
    Z = 0.25 * cos(t) + (i - 3.5) * 0.15
  ))
}
bun <- bundle(lapply(seq_len(6), strand))

# Because the tubes are fabricated by you from line-only data, prune keeps
# a spread-out subset whose fat tubes do not overlap: the extreme strands.
pruned <- prune(bun, radius = 1)
length(pruned@streamlines)
#> [1] 2
```
