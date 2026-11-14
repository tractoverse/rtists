# [`prune()`](https://tractoverse.github.io/rtists/reference/prune.md) method for `fiber::bundle_set` objects

Prunes every
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
in a
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
independently and returns a set holding the pruned (non-empty) bundles.
See [`prune()`](https://tractoverse.github.io/rtists/reference/prune.md)
for the full parameter documentation.

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
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
holding the pruned bundles; bundles pruned down to zero streamlines are
dropped.

## See also

[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md)
