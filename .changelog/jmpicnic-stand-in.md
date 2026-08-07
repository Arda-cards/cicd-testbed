### Added

- The full queued-CI/CD machinery, so the design can be exercised without
  `operations`: a `changelog-check` gate enforcing one entry by exactly one
  route, range-based assembly that composes every pending merge into a single
  release, and a synthetic build that refuses to publish from anything but an
  assembly commit.
