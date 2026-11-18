# Vendored three.js r186 licensing re-verification (release gate)

Date: 2026-11-18
Commit: `50ef388` (post PR #11 merge, main)
Provenance check per the pre-ship licensing gate: every vendored file must be
licensed to permit redistribution/embedding/re-export under the package license.

## Source of truth

npm registry tarball `three-0.186.0.tgz` (sha256 of the tarball below), the
canonical published distribution of the exact pinned version:

- package.json `license` field: `"MIT"`
- `package/LICENSE`: The MIT License, `Copyright © 2010-2026 three.js authors`
- `package/build/three.module.js` header: `@license` block,
  `Copyright 2010-2026 Three.js Authors`, `SPDX-License-Identifier: MIT`

## Byte-identical comparison (SHA-256)

All 8 vendored files under `inst/htmlwidgets/lib/threejs/` match the upstream
r186 copies exactly (no modifications, so no derivative-work license
questions arise):

| Vendored file | SHA-256 | Matches upstream r186 |
|---|---|---|
| `three.module.js` | `9052042d676cb0fdc1ddfefe193053f34b7ac0513a616fdac4535d49987812ea` | yes |
| `three.core.js` | `9edde002b066a9a05676a6127f67735b62baf399bdea529f2f7e31657da769e6` | yes |
| `jsm/lines/Line2.js` | `69dd2120d4df14208796acf199f80a64d37e042cfa65dc2b98286694b2954194` | yes |
| `jsm/lines/LineGeometry.js` | `b7ec6b0011e3b09dc72e17cfd8e8945295cb2bc8c8aa9aa19e47119680bdad7e` | yes |
| `jsm/lines/LineMaterial.js` | `d4517001f9d7b3e885ea5baa930de0077351e885db52ef4565cde4c7dd17eb23` | yes |
| `jsm/lines/LineSegments2.js` | `fcbc20f576e88343cea12131f49b7003d7ab44ede422fcb694e567456022f7a0` | yes |
| `jsm/lines/LineSegmentsGeometry.js` | `471f0a954a0c9c59d3d151392f424142a9164a722802f63b371971378a84a1b1` | yes |
| `jsm/controls/OrbitControls.js` | `3d79d07ecb686b4e5d93232eedab255331c1beef711e13164eaa1f68655a5f2b` | yes |

## Header findings

- `three.module.js` / `three.core.js`: carry the upstream `@license` block with
  `SPDX-License-Identifier: MIT` — preserved in the distributed files.
- `jsm/**` example files (Line*, OrbitControls): no per-file header upstream
  either; they are covered by the single three.js repo LICENSE (MIT, in the
  tarball's `package/LICENSE`). Since the copies are byte-identical to
  upstream, no header is missing relative to source.

## Compliance conclusion

- Upstream license (MIT, license field + LICENSE file + SPDX headers) permits
  redistribution, embedding, and re-export under the package's own MIT license
  with attribution.
- `inst/NOTICE` mirrors the upstream MIT text (`Copyright (c) 2010-2026
  Three.js Authors`) and ships with the package; README licensing section
  documents the vendoring and lists all files.
- rtists itself is MIT (`DESCRIPTION` `License: MIT + file LICENSE`), so the
  combined distribution stays MIT with no conflicting terms.

**Gate: PASS** — vendored code is licensed to permit the embedding/redistribution
form used; provenance recorded; attribution in NOTICE + README.
