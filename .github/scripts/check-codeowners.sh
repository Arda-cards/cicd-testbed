#!/usr/bin/env bash
#
# Fails when CODEOWNERS is missing or does not resolve.
#
# With `required_approving_review_count: 0` and `require_code_owner_review:
# true`, CODEOWNERS *is* the review policy — and an unresolvable owner does not
# make the rule stricter or even noisier. It makes it vacuous: the rule still
# claims to require code-owner review, and the pull request merges with no
# review at all.
#
# Measured 2026-08-06. The same pull request, the same rulesets, differing only
# in whether the owning team had repository access:
#
#   team lacked access   ->  CLEAN, zero reviews, mergeable
#   team granted access  ->  BLOCKED, review requested
#
# Nothing on the pull request distinguishes those. A renamed team, a permission
# change, or a typo turns review off and says nothing. This is what says it.
#
# The check runs against the ref under test rather than the default branch, so
# it catches a pull request that breaks or deletes the file before that becomes
# everyone's problem. It is also what lets the adopting pull request pass: the
# repository has no CODEOWNERS on `main` until this very change merges.
#
# Usage: check-codeowners.sh [ref]

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly ref="${1:-}"

query="repos/${GITHUB_REPOSITORY}/codeowners/errors"
if [ -n "${ref}" ]; then
  query+="?ref=${ref}"
fi
readonly query

# A 404 here is not "no errors" — it is "no CODEOWNERS file", which is the
# strongest form of the failure this script exists to report.
if ! response="$(gh api "${query}" 2>&1)"; then
  if grep -q "Not Found" <<<"${response}"; then
    echo "::error file=.github/CODEOWNERS::no CODEOWNERS file on ${ref:-the default branch}; code-owner review is not being enforced"
  else
    echo "::error::could not read CODEOWNERS errors: ${response}"
  fi
  exit 1
fi

errors="$(jq -c '.errors // []' <<<"${response}")"
readonly errors
count="$(jq 'length' <<<"${errors}")"
readonly count

if [ "${count}" -eq 0 ]; then
  echo "::notice::CODEOWNERS resolves on ${ref:-the default branch}"
  exit 0
fi

echo "::error::CODEOWNERS has ${count} unresolved owner(s); code-owner review is not being enforced"
jq -r '.[] | "::error file=.github/CODEOWNERS,line=\(.line)::\(.message)"' <<<"${errors}"
{
  echo "# CODEOWNERS does not resolve"
  echo
  echo "Code-owner review is silently not enforced while this is true."
  echo
  jq -r '.[] | "- line \(.line): \(.message)"' <<<"${errors}"
} >>"${GITHUB_STEP_SUMMARY}"
exit 1
