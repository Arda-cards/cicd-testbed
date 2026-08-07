### Added

- A `codeowners-check` gate that fails when CODEOWNERS does not resolve.
  With `required_approving_review_count: 0` and `require_code_owner_review:
  true`, an unresolvable owner does not make the rule stricter — it makes it
  vacuous, and the pull request merges with no review while the ruleset still
  claims to require one. Measured here: the same pull request under the same
  rulesets was mergeable with zero reviews when the owning team lacked
  repository access, and blocked once it was granted. Nothing distinguished
  those two states on the pull request itself.
