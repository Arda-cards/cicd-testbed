#!/usr/bin/env bash
#
# Composes one release block from the entries it is given, and commits it. It
# does not tag and it does not create a Release.
#
# It neither discovers the pending pull requests nor resolves their manifests.
# `pending-prs.sh` names them and `synthesize-changelog-entry` resolves them, so
# what arrives here is ENTRIES and what happens here is composition. Borrowing
# another component's implementation — checking the resolver out and calling the
# script its action wraps — is what that arrangement replaced.
#
# In this model CHANGELOG.md *is* the build-time version source, so the build
# derives the version, cuts the tag and publishes. Assembly writing the file and
# also tagging is two components claiming the same job: when both ran for real
# on 2026-08-18, assembly tagged v8.0.0 and the build then failed on the tag it
# could not create, leaving a published Release with no artifact behind it.
#
# A batch of pull requests merged together therefore produces one release rather
# than racing to produce several. The range that makes that true, and makes a
# failed run lose nothing, is `pending-prs.sh`'s business now.

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly changelog="CHANGELOG.md"
readonly changemap=".github/clq/changemap.json"
readonly changelog_dir=".changelog"
readonly assembly_prefix="chore: assemble CHANGELOG "

clq() {
  docker run --rm \
    --volume "${PWD}/${1}:/home/CHANGELOG.md:ro" \
    --volume "${PWD}/${changemap}:/home/changemap.json:ro" \
    denisa/clq:1.8.28 -changeMap /home/changemap.json "${@:2}" /home/CHANGELOG.md
}

# --- the entries, as resolved for us ------------------------------------------

readonly resolved="${ENTRIES:?ENTRIES must be set by the resolver}"

# `tostring` is not redundant defensiveness about today's producer, which emits
# `pr` as a string. It is that assembly runs only *after* merge, on main: a
# resolver that one day emitted a number would break composition at the one
# moment when the remedy is a commit on main rather than a failing check.
mapfile -t prs < <(jq -r '.[] | "#" + (.pr|tostring)' <<<"${resolved}")
if [ "${#prs[@]}" -eq 0 ]; then
  echo "::notice::no entries to assemble"
  exit 0
fi
echo "::notice::composing ${prs[*]}"

entries="$(jq -r '.[].entry' <<<"${resolved}")"

if [ -z "$(tr -d '[:space:]' <<<"${entries}")" ]; then
  echo "::notice::no entries to assemble"
  exit 0
fi

# --- merge the entries by category -------------------------------------------

# Bullets from several pull requests land under one heading each, so a release
# reads as a description of the release rather than as a list of pull requests.
merged="$(
  printf '%s' "${entries}" | awk '
    /^###[[:space:]]/ { heading = $0; sub(/[[:space:]]+$/, "", heading); next }
    /^[[:space:]]*$/  { next }
    heading != ""     { bullets[heading] = bullets[heading] $0 "\n" }
    END {
      order["### Changed"] = 1; order["### Removed"] = 2
      order["### Added"] = 3;   order["### Deprecated"] = 4
      order["### Fixed"] = 5;   order["### Security"] = 6
      for (rank = 1; rank <= 6; rank++)
        for (h in bullets)
          if (order[h] == rank) printf "%s\n\n%s\n", h, bullets[h]
    }
  '
)"
readonly merged

# --- compose, validate, commit ----------------------------------------------

work="$(mktemp -d)"
{
  head -n "$(($(grep -n '^## \[' "${changelog}" | head -1 | cut -d: -f1) - 1))" "${changelog}"
  echo "## [0.0.0] - $(git log -1 --format=%cs HEAD)"
  echo
  printf '%s\n' "${merged}"
  # Command substitution strips trailing newlines, so the blank line that
  # separates this block from the release below it has to be put back. Without
  # it the composed entry runs straight into the next `## [` heading — valid
  # enough for clq to accept, and wrong in a file people read.
  echo
  tail -n +"$(grep -n '^## \[' "${changelog}" | head -1 | cut -d: -f1)" "${changelog}"
} >"${work}/candidate.md"

# clq computes the version from the categories present, so the placeholder above
# exists only to give it a well-formed document to read. The author never picks
# a version; the change kinds decide it.
version="$(clq "${changelog}" -query 'releases[0].version')"
readonly version
next="$(
  printf '%s\n' "${merged}" | awk -v current="${version}" '
    /^### (Changed|Removed)/    { bump = 3 }
    /^### (Added|Deprecated)/   { if (bump < 2) bump = 2 }
    /^### (Fixed|Security)/     { if (bump < 1) bump = 1 }
    END {
      split(current, v, ".")
      if (bump == 3) printf "%d.0.0\n", v[1] + 1
      else if (bump == 2) printf "%d.%d.0\n", v[1], v[2] + 1
      else printf "%d.%d.%d\n", v[1], v[2], v[3] + 1
    }
  '
)"
readonly next

sed -i "s|^## \[0\.0\.0\] - |## [${next}] - |" "${work}/candidate.md"
cp "${work}/candidate.md" "${changelog}"

if ! clq "${changelog}" -release >/dev/null; then
  echo "::error::the assembled CHANGELOG.md is not valid"
  exit 1
fi
echo "::notice::assembled ${next} from ${prs[*]}"

# The pending entries are consumed, not archived: main does not keep a
# .changelog file, so a stale one can never be assembled twice. The merge
# commit carries it until this commit removes it.
if compgen -G "${changelog_dir}/*.md" >/dev/null; then
  find "${changelog_dir}" -name '*.md' ! -name 'README.md' -delete
fi

git config user.name "arda-changelog-bot[bot]"
git config user.email "arda-changelog-bot[bot]@users.noreply.github.com"
git add "${changelog}" "${changelog_dir}"
git commit -m "${assembly_prefix}${next}

Covers ${prs[*]}."
# main can advance while this runs — a merge landing between the checkout and
# the push makes it a non-fast-forward. Rebase onto whatever arrived and try
# again rather than leaving the release unwritten. Concurrency serialises
# assembly runs, so the only thing that can have moved is a merge, and rebasing
# a changelog prepend over one is what git is good at.
for attempt in 1 2 3; do
  if git push origin HEAD:main; then
    break
  fi
  if [ "${attempt}" -eq 3 ]; then
    echo "::error::main moved under this assembly three times; the entries stay pending for the next run"
    exit 1
  fi
  echo "::warning::main advanced; rebasing and retrying (attempt ${attempt})"
  git fetch origin main
  if ! git rebase origin/main; then
    git rebase --abort || true
    echo "::error::could not rebase the assembly onto main; the entries stay pending for the next run"
    exit 1
  fi
done

# No tag, and no Release. The build derives the version from the file this
# commit just wrote, and publishing is its job alone.
echo "::notice::${next} written; the build publishes it"
