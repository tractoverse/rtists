# rtists [![rtists website](reference/figures/logo.png)](https://astamm.github.io/rtists/)

**rtists** (*R for Tissue Integrity Superimposed on Tractography
Streamlines*) provides interactive 3-D visualisation of tractography
streamlines and bundles defined in the
[riot](https://github.com/astamm/riot) package.

The main function is
[`plot3d()`](https://astamm.github.io/rtists/reference/plot3d.md), an
[S7](https://rconsortium.github.io/S7/) generic with methods for both
[`riot::streamline`](https://astamm.github.io/riot/reference/streamline.html)
and
[`riot::bundle`](https://astamm.github.io/riot/reference/bundle.html)
objects. Figures are rendered by [plotly](https://plotly.com/r/) and are
fully interactive (pan, rotate, zoom).

## Installation

Install the development version from
[GitHub](https://github.com/astamm/rtists):

``` r

# install.packages("pak")
pak::pak("astamm/rtists")
```

## Usage

### Build some riot objects

``` r

library(rtists)
library(riot)

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

set.seed(42)
bun <- new_bundle(lapply(seq_len(6), function(i) {
  noise <- matrix(rnorm(nrow(pts) * 3, sd = 0.2), ncol = 3)
  colnames(noise) <- c("X", "Y", "Z")
  new_streamline(
    points          = pts + noise,
    point_data      = list(FA = pmin(pmax(sl@point_data$FA + rnorm(6, sd = 0.05), 0), 1)),
    streamline_data = list(mean_FA = mean(sl@point_data$FA))
  )
}))
```

### `plot3d()` — colour modes

#### Default: orientation colours

Each point is coloured by the direction of the local tangent vector
using the standard DTI convention (left–right = red, anterior–posterior
= green, superior–inferior = blue):

``` r

plot3d(bun)
```

![](reference/figures/README-orientation-1.png)

#### Colour by per-point metadata

Pass any key from `@point_data` to map a continuous scalar to a colour
scale:

``` r

plot3d(bun, color = "FA", palette = "Viridis")
```

![](reference/figures/README-point-fa-1.png)

#### Colour by per-streamline metadata

Keys from `@streamline_data` are broadcast to all points of each
streamline, giving every tract a single uniform colour:

``` r

plot3d(bun, color = "mean_FA", palette = "RdYlBu")
```

![](reference/figures/README-streamline-fa-1.png)

#### Fixed colour

Any CSS colour name or hex code colours all lines identically:

``` r

plot3d(bun, color = "steelblue", opacity = 0.7, linewidth = 3)
```

![](reference/figures/README-fixed-1.png)

## Colour modes at a glance

| `color` value | Behaviour |
|----|----|
| `"orientation"` (default) | Per-point RGB from local fibre direction |
| Name of a `@point_data` key | Continuous or categorical scale per point |
| Name of a `@streamline_data` key | Uniform colour per streamline |
| CSS / hex string (e.g. `"steelblue"`) | Fixed colour for all lines |

Additional arguments (`palette`, `linewidth`, `opacity`, `...`) are
documented in
[`?plot3d`](https://astamm.github.io/rtists/reference/plot3d.md).
