### Changed

- CODEOWNERS now covers `/.github/` alone rather than everything. Ownership of
  every path made code-owner review mandatory on every pull request, which no
  waiver can lift — `enqueuePullRequest` refuses a pull request awaiting
  code-owner review regardless of who asks. Scoping ownership to the machinery
  that enforces policy leaves the general review requirement to a gate that can
  be waived, while the gate's own source cannot be altered without a review
  nobody can waive.
