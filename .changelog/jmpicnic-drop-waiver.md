### Removed

- The `/waive-review` command and the `review-required-gate` check. The waiver
  could not work: `enqueuePullRequest` refuses a pull request awaiting
  code-owner review regardless of who asks, and a bypass actor cannot merge
  directly either because the merge-queue rule belongs to a ruleset it does not
  bypass. Both were measured rather than inferred. Without a waiver there is no
  reason to split the rulesets, no bypass identity to create, and no need for a
  label demanding a human where code-owner review already demands one.

### Changed

- CODEOWNERS covers every path again. Scoping it to `/.github/` existed only to
  leave room for a waivable general-review gate; with no waiver, owning
  everything is both simpler and stricter, and it closes the hole that a pull
  request can rewrite the gate that is gating it.
