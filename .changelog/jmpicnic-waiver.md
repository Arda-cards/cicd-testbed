### Added

- The `/waive-review` command, letting a code owner enqueue a pull request on
  their own authority instead of on an approval. The commenter must appear in
  CODEOWNERS' `*` entry, the category must be one of `hotfix`, `linting-only`
  or `external-review`, and the justification must be substantive. The identity
  that enqueues holds bypass on the review ruleset alone, so a waived pull
  request still passes every check and resolves every thread — the waiver
  removes the reviewer, not the gates.
