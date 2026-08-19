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

## [4.2.0] - 2026-08-19

### Added

- Batch entry a, written as a file so the merge group stages two of them.

## [4.1.0] - 2026-08-19

### Added

- The build resolves the feature-build marker from the changelog manifest and publishes a prerelease that reaches `dev` alone, so a marked branch cannot reach a further environment by omission.

### Fixed

- The changelog manifest is resolved by one component and consumed by the merge gate, the build and the assembly, rather than parsed independently by each of them. A marker written in a pull-request body is now read and honoured instead of being ignored by everything that needed it.
- A branch is ambiguous when it carries more than one feature-build marker, not when it carries more than one changelog file. Counting files failed the build whenever a merge batch staged two entries together, with nothing wrong with either.
- Assembly writes `CHANGELOG.md` and stops, leaving the tag and the Release to the build that derives the version from it. It also bounds its range on its own previous commit rather than on the last release tag, so a build failing after a successful assembly cannot make the next run collect entries twice.
> [!note]
> Authored by Claude Opus 5 for jmpicnic

## [4.0.0] - 2026-08-07

### Changed

- One required check, `merge-eligibility`, replaces `changelog-check`,
  `draft-check` and `codeowners-check`. They shared a trigger that must not
  drift and duplicated the merge-queue pull-request resolution between two of
  them — the dangerous kind of duplication, since fixing one copy and not the
  other leaves a gate reporting success without having evaluated a queued entry.
  Three required check names were also three strings that must exist on `main`
  and match the ruleset exactly. The assertions themselves are unchanged; they
  now live in `.github/scripts/` as shell, leaving the workflow a thin trigger.

### Added

- `assemble.sh` rebases and retries when `main` advances under it. Concurrency
  serialises assembly runs, so the only thing that can have moved is a merge,
  and rebasing a changelog prepend over one is what git is good at. Without it a
  merge landing between the checkout and the push left the release unwritten.
- `changelog-assembly` re-checks CODEOWNERS after the merge. Owners can break
  between a pull request passing and the next one opening — a team renamed,
  access revoked — and the pre-merge gate cannot see that.

### Fixed

- The README describes what the repository *is*: a working reference
  implementation of the queued CI/CD model, not only a place to run experiments.
  It now inventories the model's parts and carries every finding measured so
  far, including four that were only in the project's design document.
- The gate checks CODEOWNERS on the ref under test rather than on the default
  branch. Querying the default branch means a repository adopting the model
  404s on the very pull request that installs the file, and a pull request that
  breaks or deletes CODEOWNERS is caught only after it has merged.
- `changelog-entry.sh` reports its refusals on stderr. Every caller reads the
  entry through command substitution, so a message on stdout was captured as if
  it were the entry and the author was left with a bare exit code.

## [3.0.0] - 2026-08-07

### Changed

- CODEOWNERS covers every path again. Scoping it to `/.github/` existed only to
  leave room for a waivable general-review gate; with no waiver, owning
  everything is both simpler and stricter, and it closes the hole that a pull
  request can rewrite the gate that is gating it.

### Removed

- The `/waive-review` command and the `review-required-gate` check. The waiver
  could not work: `enqueuePullRequest` refuses a pull request awaiting
  code-owner review regardless of who asks, and a bypass actor cannot merge
  directly either because the merge-queue rule belongs to a ruleset it does not
  bypass. Both were measured rather than inferred. Without a waiver there is no
  reason to split the rulesets, no bypass identity to create, and no need for a
  label demanding a human where code-owner review already demands one.

### Fixed

- `qualify` tracks the released `qualify-build-action@v2` again. It was left
  pinned to the `jmpicnic/pr-body-changelog` work branch, which was deleted when
  that work merged, so every queued entry failed to resolve the action and was
  dropped from the queue.

## [2.0.1] - 2026-08-07

### Fixed

- Nothing; a pull request touching no owned path, used to check that ordinary
  changes can still reach the queue under scoped ownership.

## [2.0.0] - 2026-08-07

### Changed

- CODEOWNERS now covers `/.github/` alone rather than everything. Ownership of
  every path made code-owner review mandatory on every pull request, which no
  waiver can lift — `enqueuePullRequest` refuses a pull request awaiting
  code-owner review regardless of who asks. Scoping ownership to the machinery
  that enforces policy leaves the general review requirement to a gate that can
  be waived, while the gate's own source cannot be altered without a review
  nobody can waive.

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
