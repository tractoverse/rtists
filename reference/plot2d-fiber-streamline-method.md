# [`plot2d()`](https://tractoverse.github.io/rtists/reference/plot2d.md) method for `fiber::streamline` objects

Renders a single
[fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html)
as a 2D arclength projection. See
[`plot2d()`](https://tractoverse.github.io/rtists/reference/plot2d.md)
for the full parameter documentation and examples.

## Arguments

- x:

  A
  [fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html)
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

t   <- seq(0, 4 * pi, length.out = 200)
pts <- cbind(
  X = seq_len(200) * 0.1,
  Y = 0.5 * sin(t),
  Z = 0.5 * cos(t)
)
sl <- streamline(
  points          = pts,
  point_data      = list(FA = 0.4 + 0.3 * sin(t / 2)),
  streamline_data = list(mean_FA = 0.5)
)

plot2d(sl)

plot2d(sl, color = "FA")

plot2d(sl, color = "steelblue")

```
