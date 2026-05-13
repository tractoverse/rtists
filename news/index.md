# Changelog

## rtists 0.1.0

- Initial CRAN release.
- Added
  [`plot3d()`](https://astamm.github.io/rtists/reference/plot3d.md), an
  [S7](https://rconsortium.github.io/S7/) generic with methods for
  [`fiber::streamline`](https://astamm.github.io/fiber/reference/streamline.html)
  and
  [`fiber::bundle`](https://astamm.github.io/fiber/reference/bundle.html)
  objects.
- Colour modes supported by
  [`plot3d()`](https://astamm.github.io/rtists/reference/plot3d.md):
  - `"orientation"` (default): per-point RGB colour derived from the
    local fibre direction using the standard DTI convention (left–right
    = red, anterior–posterior = green, superior–inferior = blue).
  - Metadata key: any key from `@point_data` or `@streamline_data` can
    be mapped to a continuous (`palette`) or categorical colour scale.
  - Fixed colour: any CSS colour name or hex string.
- All streamlines in a bundle are rendered as a single `scatter3d` trace
  separated by `NA` break-points, keeping the widget lightweight for
  large bundles.
- Interactive figures are produced by [plotly](https://plotly.com/r/)
  and support pan, rotate, and zoom.
