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

## [1.4.0] - 2026-08-07

### Added

- The `/waive-review` command, letting a code owner enqueue a pull request on
  their own authority instead of on an approval. The commenter must appear in
  CODEOWNERS' `*` entry, the category must be one of `hotfix`, `linting-only`
  or `external-review`, and the justification must be substantive. The identity
  that enqueues holds bypass on the review ruleset alone, so a waived pull
  request still passes every check and resolves every thread — the waiver
  removes the reviewer, not the gates.

## [1.3.0] - 2026-08-07

### Added

- A `draft-check` gate that fails when a queued pull request is a draft, and
  restores the gate delay to zero. GitHub does not enforce this: a queued pull
  request converted back to draft was measured staying in the queue, running
  every check, and merging — `isDraft: true`, `state: MERGED`, with a release
  cut from it. Failing a required check is also the eviction mechanism, since
  the queue will not eject a drafted entry but does eject one whose checks fail.
- A `review-required-gate` check, so an author can demand a human review on a
  change that ownership rules alone would let through. It passes when the
  `REVIEW-REQUIRED` label is absent, and when present only once a human has
  approved — a bot approval does not count, since the label exists precisely to
  put a person in the loop.
- A `codeowners-check` gate that fails when CODEOWNERS does not resolve. With
  `required_approving_review_count: 0` and `require_code_owner_review: true`,
  an unresolvable owner does not make the rule stricter — it makes it vacuous,
  and the pull request merges with no review while the ruleset still claims to
  require one. Measured here: the same pull request under the same rulesets was
  mergeable with zero reviews when the owning team lacked repository access, and
  blocked once it was granted. Nothing distinguished those two states on the
  pull request itself.

## [1.2.2] - 2026-08-07

### Fixed

- Slowed one synthetic gate so a queued entry stays in the queue long enough to
  be interfered with. Needed to answer whether GitHub ejects a pull request that
  is returned to draft while queued, which the design assumes but had never
  observed.

## [1.2.1] - 2026-08-07

### Fixed

- An assembled release block is now separated from the release below it by a
  blank line. Command substitution strips trailing newlines, so the block ran
  straight into the next `## [` heading — which `clq` accepts and a reader does
  not. `CHANGELOG.md` is a published artifact; a formatting artifact of how it
  was composed does not belong in it.

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
