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
    `thickness > 0` draws real world-space tubes with per-point colour
    and object-level depth-sorted transparency; the fast line mode
    scales to large bundles.
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
