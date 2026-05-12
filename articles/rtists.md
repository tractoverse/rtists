# Getting started with rtists

``` r

if (!requireNamespace("rtists", quietly = TRUE)) {
  knitr::opts_chunk$set(eval = FALSE)
} else {
  library(rtists)
  library(fiber)
}
```

## Overview

**rtists** (*R for Tissue Integrity Superimposed on Tractography
Streamlines*) provides interactive 3-D visualisation of tractography
data defined in the [fiber](https://github.com/astamm/fiber) package.
The central function is
[`plot3d()`](https://astamm.github.io/rtists/reference/plot3d.md), a
[S7](https://rconsortium.github.io/S7/) generic with methods for the two
core fiber classes:

| Class | Description |
|----|----|
| [`fiber::streamline`](https://astamm.github.io/fiber/reference/streamline.html) | A single fibre tract — an ordered sequence of 3-D points plus optional metadata. |
| [`fiber::bundle`](https://astamm.github.io/fiber/reference/bundle.html) | An ordered collection of streamlines representing a white-matter bundle. |

The interactive figures are produced by [plotly](https://plotly.com/r/),
so they can be panned, rotated, and zoomed directly in the browser or
the RStudio / Positron viewer pane.

------------------------------------------------------------------------

## Data structures

A `streamline` stores three compartments, all accessible with the `@`
operator:

- `@points` — an $`n \times 3`$ numeric matrix with columns `X`, `Y`,
  `Z`.
- `@point_data` — a named list of per-point numeric vectors (length
  $`n`$), e.g. fractional anisotropy (FA) sampled along the tract.
- `@streamline_data` — a named list of numeric scalars (length 1),
  e.g. a tract-level mean FA.

A `bundle` holds:

- `@streamlines` — a list of `streamline` objects.
- `@bundle_data` — a named list of bundle-level metadata.

### Creating a minimal example

``` r

pts <- matrix(
  c(
    0, 0, 0,
    1, 2, 1,
    2, 3, 3,
    3, 3, 5,
    4, 2, 6,
    5, 1, 7
  ),
  ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)

sl <- new_streamline(
  points          = pts,
  point_data      = list(FA = c(0.25, 0.40, 0.65, 0.70, 0.55, 0.30)),
  streamline_data = list(mean_FA = 0.475)
)

sl
#> <streamline [6 pts] | point: FA | streamline: mean_FA>
```

A bundle is just a list of streamlines wrapped by
[`new_bundle()`](https://astamm.github.io/fiber/reference/new_bundle.html):

``` r

# Simulate a small bundle of four slightly perturbed copies
set.seed(42)
streamlines <- lapply(seq_len(4), function(i) {
  noise <- matrix(rnorm(nrow(pts) * 3, sd = 0.15), ncol = 3)
  colnames(noise) <- c("X", "Y", "Z")
  new_streamline(
    points          = pts + noise,
    point_data      = list(FA = pmin(pmax(sl@point_data$FA + rnorm(6, sd = 0.05), 0), 1)),
    streamline_data = list(mean_FA = mean(sl@point_data$FA))
  )
})

bun <- new_bundle(streamlines)
bun
#> <bundle [4 streamlines | 6–6 pts/streamline] | point: FA | streamline: mean_FA>
```

------------------------------------------------------------------------

## Plotting with `plot3d()`

### Default: colour by local orientation

With no `color` argument, each point is coloured by the direction of the
local tangent vector. Absolute values of the normalised $`(dx, dy, dz)`$
are mapped to the R, G, B channels — the standard DTI convention
(left–right = red, anterior–posterior = green, superior–inferior =
blue).

``` r

plot3d(sl)
```

Figure 1: Single streamline coloured by local fibre orientation.

The same default works for a whole bundle:

``` r

plot3d(bun)
#> ℹ Rendering 4 streamlines...
```

Figure 2: Bundle of four streamlines coloured by orientation.

### Colour by per-point metadata

Pass any key from `@point_data` as the `color` argument. Numeric values
are mapped to a continuous colour scale (default: `"Viridis"`).

``` r

plot3d(sl, color = "FA")
```

Figure 3: Streamline coloured by per-point FA.

### Colour by per-streamline metadata

Keys from `@streamline_data` are broadcast to every point of that
streamline, so they work equally well as a colour aesthetic. For a
bundle this gives each streamline a single uniform colour that reflects
its tract-level scalar.

``` r

plot3d(bun, color = "mean_FA", palette = "RdYlBu")
#> ℹ Rendering 4 streamlines...
```

Figure 4: Bundle coloured by per-streamline mean FA.

### Fixed colour

Pass any CSS colour name or hex code to colour all lines identically.

``` r

plot3d(bun, color = "steelblue", opacity = 0.6)
#> ℹ Rendering 4 streamlines...
```

Figure 5: Bundle in a single fixed colour with reduced opacity.

------------------------------------------------------------------------

## Appearance options

| Argument | Default | Description |
|----|----|----|
| `color` | `"orientation"` | Colour mode: `"orientation"`, metadata key, or a CSS/hex string. |
| `palette` | `"Viridis"` | Plotly / ColorBrewer scale used for continuous numeric metadata. |
| `linewidth` | `2` | Line width in pixels. |
| `opacity` | `0.5` | Global line opacity (0–1). |
| `...` |  | Passed to `plotly::layout()`, e.g. `title = "Left CST"`. |

Extra `plotly::layout()` arguments can be supplied directly:

``` r

plot3d(bun, color = "FA", linewidth = 4, title = "Example bundle — FA")
#> ℹ Rendering 4 streamlines...
```

Figure 6: Custom title and increased line width.
