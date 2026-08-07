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
