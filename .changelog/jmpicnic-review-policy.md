### Added

- A `review-required-gate` check, so an author can demand a human review on a
  change that ownership rules alone would let through. It passes when the
  `REVIEW-REQUIRED` label is absent, and when present only once a human has
  approved — a bot approval does not count, since the label exists precisely to
  put a person in the loop.
