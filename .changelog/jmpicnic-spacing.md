### Fixed

- An assembled release block is now separated from the release below it by a
  blank line. Command substitution strips trailing newlines, so the block ran
  straight into the next `## [` heading — which `clq` accepts and a reader does
  not. `CHANGELOG.md` is a published artifact; a formatting artifact of how it
  was composed does not belong in it.
