# [`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md) method for `fiber::bundle_set` objects

Renders all bundles in a
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
as a single interactive 3D line plot. Each bundle in the set (typically
one per subject or session) can be coloured uniformly by its bundle name
or with the same per-streamline colouring as
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
for
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
objects. See
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
for the full parameter documentation.

## Arguments

- x:

  A
  [fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  object.

- color:

  Controls how streamline colours are assigned. Accepted values:

  - `"orientation"` (default): per-point RGB colour derived from the
    local fibre direction. The absolute values of the normalised tangent
    vector \\(\|dx\|, \|dy\|, \|dz\|)\\ are mapped to the R, G, B
    channels — the standard DTI colour convention (left-right = red,
    anterior-posterior = green, superior-inferior = blue).

  - A **metadata key**: a string matching a key in `@point_data`
    (per-point scalar) or `@streamline_data` (per-streamline scalar,
    broadcast to all points). Numeric values are mapped to a continuous
    colour scale (`palette`); character values are coloured
    categorically.

  - A **CSS/hex colour string**: e.g. `"#E69F00"` or `"steelblue"`. All
    lines are drawn in that fixed colour.

- palette:

  A [plotly](https://rdrr.io/pkg/plotly/man/plotly.html) / ColorBrewer
  colour scale name applied when `color` is a numeric metadata key.
  Defaults to `"Viridis"`.

- linewidth:

  Numeric. Width of the plotted lines. Defaults to `2`.

- opacity:

  Numeric in \[0, 1\]. Global line opacity. Defaults to `0.5`.

- color_by_bundle:

  Logical. When `TRUE`, every streamline is coloured by its parent
  bundle name (one distinct colour per entry in the set), overriding the
  `color` argument. When `FALSE` (default), `color` is applied as-is,
  inheriting the same per-streamline colouring behaviour as the
  [fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
  method.

- ...:

  Additional named arguments forwarded to `plotly::layout()`, e.g.
  `title = "My bundle"`.

## Value

An interactive [plotly](https://rdrr.io/pkg/plotly/man/plotly.html)
htmlwidget.

## See also

[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
