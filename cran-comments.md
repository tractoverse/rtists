## Test environments

* Local, macOS: R 4.6.1
* Continuous integration, GitHub Actions (`R-CMD-check.yaml`):
  * macOS (latest), R release
  * Windows (latest), R release
  * Ubuntu (latest), R devel
  * Ubuntu (latest), R release
  * Ubuntu (latest), R oldrel-1
* R-hub (all check platforms): R release and R devel
* win-builder: R devel and R release

## R CMD check results

0 errors | 0 warnings | 0 notes

## Known R-hub failures (environmental, not package defects)

Three `linux-containers` jobs on R-hub (`rhub.yaml`) fail for reasons that are
upstream or environmental rather than defects in this package. None touches R
code in the package. Details:

* **gcc13 (Fedora 38)** fails during lazy-load of the `fiber` dependency: its
  prebuilt `fiber.so` needs Intel's `libsvml.so`, which is absent from the
  Fedora 38 container. The failing `.so` is a cached binary restored from the
  R-hub package cache, not built by this package.
* **nosuggests (Fedora 44)** shows the same pattern: `fiber.so` needs
  `libasan.so.8`, missing from the Fedora 44 container.
* **rchk** has no native code to scan: rtists is pure R with no `src/`
  directory and no `.Call`, `.C`, or `.Fortran` entry points, so the `bcheck`
  step warns "bcheck output file does not exist". rchk cannot inspect a
  package that ships no compiled code.

These reflect R-hub container or upstream dependency availability. On a clean
macOS environment, and on the GitHub Actions and win-builder platforms above,
the package checks cleanly with 0 errors, 0 warnings, and 0 notes.
