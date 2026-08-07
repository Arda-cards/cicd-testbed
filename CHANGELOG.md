# changelog

[![Keep a Changelog](https://img.shields.io/badge/Keep%20a%20Changelog-1.0.0-informational)](https://keepachangelog.com/en/1.0.0/)
[![Semantic Versioning](https://img.shields.io/badge/Semantic%20Versioning-2.0.0-informational)](https://semver.org/spec/v2.0.0.html)

Keep the newest entry at top, format date according to ISO 8601: `YYYY-MM-DD`.

Categories, defined in [changemap.json](.github/clq/changemap.json):

- *major* release trigger:
  - `Changed` for changes in existing functionality.
  - `Removed` for now removed features.
- *minor* release trigger:
  - `Added` for new features.
  - `Deprecated` for soon-to-be removed features.
- *bugfix* release trigger:
  - `Fixed` for any bugfixes.
  - `Security` in case of vulnerabilities.

## [1.2.0] - 2026-08-07

### Added

- The full queued-CI/CD machinery, so the design can be exercised without
  `operations`: a `changelog-check` gate enforcing one entry by exactly one
  route, range-based assembly that composes every pending merge into a single
  release, and a synthetic build that refuses to publish from anything but an
  assembly commit.

### Fixed

- Assembly now bounds its range by the last release tag rather than by the last
  assembly commit. A repository adopting the model has no assembly commit, so
  the previous reading made the first range the entire history — including
  merges that predate the model and carry no entry to collect. The first run in
  this repository failed exactly that way. In steady state the two readings
  agree, because assembly is what creates the tag.
## [1.1.0] - 2026-08-07

### Added

- Exercise `qualify-build-action` against every event it supports, so a change
  to it can be observed under a real merge queue before it is released.

## [1.0.0] - 2026-08-06

### Added

- Synthetic gates and an event-context dump, so platform behaviour can be
  observed in seconds rather than inferred.
