# [`plot2d()`](https://tractoverse.github.io/rtists/reference/plot2d.md) method for `fiber::bundle_set` objects

Renders all bundles in a
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
as a 2D arclength projection, with one facet per coordinate column. Each
bundle can be coloured uniformly by its bundle name or with the same
per-streamline colouring as
[`plot2d()`](https://tractoverse.github.io/rtists/reference/plot2d.md)
for
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
objects.

## Arguments

- x:

  A
  [fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  object.

- facet:

  Character. Which coordinate columns to draw as facets. Defaults to
  `c("X", "Y", "Z")`, stacked top to bottom; pass `"X"` (or any subset)
  for a single facet.

- color:

  Controls how the line colour is assigned. Accepted values:

  - `"orientation"` (default): point colour encodes the local fibre
    direction, mapped through the standard DTI (left–right = red,
    anterior–posterior = green, superior–inferior = blue) convention.

  - A **metadata key**: a string matching a key in `@point_data`
    (per-point scalar, averaged per chunk) or `@streamline_data` /
    `@bundle_data` (a single constant per streamline, broadcast to its
    points). Numeric values are mapped through `palette`; character
    values are coloured categorically. This is the natural way to
    overlay an FA or MD profile on a tract.

  - A **CSS/hex colour string**: e.g. `"#E69F00"` or `"steelblue"`. All
    lines are drawn in that fixed colour.

- palette:

  A colour scale name applied when `color` is a numeric metadata key.
  Resolved through
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html).
  Defaults to `"Viridis"`.

- n_chunks:

  Numeric. Number of equal-arclength chunks to average each streamline
  into (default 100). Lower for lighter figures, higher for finer
  geometry. The chunk count is capped at the streamline's point count.

- linewidth:

  Numeric. Width of the drawn lines, in ggplot2 units (roughly
  millimetres). Defaults to `0.5`.

- alpha:

  Numeric in \[0, 1\]. Line opacity. Defaults to `1`.

- color_by_bundle:

  Logical. When `TRUE`, every streamline is coloured by its parent
  bundle name (one distinct colour per entry in the set), overriding the
  `color` argument.

- ...:

  Additional named arguments passed to
  [`ggplot2::facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
  (for example `scales = "free_y"`).

## Value

A
[`ggplot2::ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
figure with one facet per coordinate column.

## See also

[`plot2d()`](https://tractoverse.github.io/rtists/reference/plot2d.md)

## Examples

``` r
library(fiber)

cst_sl <- function(i) {
  t   <- seq(-1, 1, length.out = 120)
  fan <- (t + 1) / 2
  streamline(cbind(
    X = 0.5 * sin(0.7 * t) + (i - 3.5) * 0.22 * (0.30 + 0.85 * fan),
    Y = 0.4 * cos(0.5 * t) + (i - 3.5) * 0.10 * (0.30 + 0.85 * fan),
    Z = 4 * t
  ))
}
cc_sl <- function(i) {
  t <- seq(-1, 1, length.out = 120)
  streamline(cbind(
    X = 6 * t,
    Y = 0.35 * t * t + (i - 3.5) * 0.18 * (1 + 0.4 * abs(t)),
    Z = 0.3 * sin(pi * t) + (i - 3.5) * 0.12
  ))
}
cst <- bundle(lapply(seq_len(8), cst_sl))
cc  <- bundle(lapply(seq_len(8), cc_sl))
cs  <- bundle_set(list(CST = cst, CC = cc))

plot2d(cs)
#> ℹ Rendering 16 streamlines across 2 bundles...

plot2d(cs, color_by_bundle = TRUE)
#> ℹ Rendering 16 streamlines across 2 bundles...

```
