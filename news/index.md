# Changelog

## rtists 0.1.0

- Initial CRAN release.
- Added
  [`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md),
  an [S7](https://rconsortium.github.io/S7/) generic with methods for
  [`fiber::streamline`](https://tractoverse.github.io/fiber/reference/streamline.html),
  [`fiber::bundle`](https://tractoverse.github.io/fiber/reference/bundle.html),
  and
  [`fiber::bundle_set`](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  objects.
- Two htmlwidget backends are available through `backend` (three.js is
  the default):
  - `"threejs"`: a self-contained three.js renderer (no CDN).
    `radius > 0` draws real world-space tubes with per-point colour and
    object-level depth-sorted transparency; the fast line mode scales to
    large bundles.
  - `"plotly"`: a single `scatter3d` trace separated by `NA`
    break-points, retained as an interim fallback.
- Colour modes supported by
  [`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md):
  - `"orientation"` (default): per-point RGB colour derived from the
    local fibre direction using the standard DTI convention (left–right
    = red, anterior–posterior = green, superior–inferior = blue).
  - Metadata key: any key from `@point_data` or `@streamline_data` can
    be mapped to a continuous (`palette`) or categorical colour scale.
  - Fixed colour: any CSS colour name or hex string.
- Interactive figures support pan, rotate, and zoom.
- The three.js backend now shows an on-scene toolbar (top-left,
  plotly-style) with controls to toggle the coordinate axes, download
  the view as a PNG, choose an orbit mode (rotate / pan / zoom), zoom in
  and out, re-frame the view to the data, and reset the camera. Disable
  it with `plot3d(..., toolbar = FALSE)`.
- The three.js legend panel includes a palette picker: a swatch icon per
  available palette, clickable to re-ramp the fibres live. It applies to
  continuous attributes, discrete (categorical) attributes, and
  per-bundle colouring alike, and it is seeded with the initial colour
  mapping from
  [`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md).
  The curated set defaults to the CVD-safe perceptual palettes (Viridis,
  Plasma, Inferno, Cividis, Mako, Rocket, Mint), each flagged as such in
  the picker, alongside the diverging RdYlBu and Spectral.
- Thin-line rendering is no longer scale-blind: when no `radius` is
  supplied (the fast line2 path), the default `linewidth` is auto-sized
  to approximately 0.5% of the scene’s bounding-box diagonal instead of
  a fixed 2 world units. A 2-unit slab was a hairline on a full-size DTI
  scene but covered most of the viewport on unit-scale synthetic
  scenarios, drawing giant overlapping quads and slowing rendering. Pass
  an explicit numeric `linewidth` to keep exact world-unit widths; the
  plotly backend uses a fixed width of 2 pixels when `linewidth` is left
  automatic.
- Added
  [`plot2d()`](https://tractoverse.github.io/rtists/reference/plot2d.md),
  an [S7](https://rconsortium.github.io/S7/) generic with methods for
  [`fiber::streamline`](https://tractoverse.github.io/fiber/reference/streamline.html),
  [`fiber::bundle`](https://tractoverse.github.io/fiber/reference/bundle.html),
  and
  [`fiber::bundle_set`](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  objects. It renders a static [ggplot2](https://ggplot2.tidyverse.org/)
  arclength projection: each streamline is re-parametrized by distance
  travelled along the fibre and the X/Y/Z coordinates are drawn against
  it in three vertically stacked facets, making it easy to compare tract
  geometry with per-point diffusion profiles (FA, MD). Geometries are
  downsampled into equal-arclength chunks (`n_chunks`), and the same
  colour vocabulary as
  [`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
  applies: orientation (DTI convention), any metadata key (continuous or
  categorical), or a fixed colour.

### Bug fixes

- The static (non-Shiny) htmlwidgets path is fixed: with the three.js
  backend, the ESM renderer module is imported asynchronously, which can
  register its widget binding after htmlwidgets’ initial
  `staticRender()` (run once on DOMContentLoaded). The console and
  Viewer pane therefore produced no canvas and no error. The loader now
  re-invokes Shiny’s binding scan or `HTMLWidgets.staticRender()` once
  the module is ready. The re-render is idempotent, so other widgets are
  left untouched.
- Named bundles are honoured correctly in
  [`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md):
  the per-bundle input names recorded by
  [`fiber::bundle_set()`](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  are now read from the right slot (`@bundle_data`), so a `bundle_set`
  built from a named list keeps its names instead of falling back to
  sequential indices.
- The three.js legend no longer lists the bundle name twice: for
  `bundle_set` objects the dedicated per-bundle “Bundle” colour mode and
  visibility list already cover `BundleName`, so the name is excluded
  from the attribute “Color by” entries. A `bundle_set` with no other
  attributes still ships the per-bundle payload so the legend can show
  and toggle bundles.
