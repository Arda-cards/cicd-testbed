### Added

- A `draft-check` gate that fails when a queued pull request is a draft, and
  restores the gate delay to zero. GitHub does not enforce this: a queued pull
  request converted back to draft was measured staying in the queue, running
  every check, and merging — `isDraft: true`, `state: MERGED`, with a release
  cut from it. Failing a required check is also the eviction mechanism, since
  the queue will not eject a drafted entry but does eject one whose checks fail.
