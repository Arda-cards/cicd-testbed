#!/usr/bin/env bash
#
# Composes one release block from every merge since the previous assembly, then
# commits, tags, and creates the GitHub Release.
#
# The range is the point. Taking "every merge since the last assembly commit"
# rather than "the merge that triggered this run" means a failed run loses
# nothing: its entries are still pending, and the next run collects them. It
# also means a batch of pull requests merged together produces one release
# rather than racing to produce several.

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

# --- the range ---------------------------------------------------------------

# The last release tag bounds the range: everything published is behind it,
# everything pending is ahead. In steady state that is the previous assembly,
# because assembly is what creates the tag.
#
# It is deliberately not "the previous assembly commit". A repository adopting
# this model has no assembly commit, so that reading makes the first range the
# entire history — including merges that predate the model and have no entry to
# collect. The last hand-made release tag is exactly the right boundary on the
# first run and stays right on every run after it.
previous="$(git describe --tags --abbrev=0 2>/dev/null || true)"

if [ -n "${previous}" ]; then
  readonly range="${previous}..HEAD"
else
  readonly range="HEAD"
fi
echo "::notice::assembling range ${range}"

mapfile -t merges < <(git log --merges --format='%H' "${range}")

if [ "${#merges[@]}" -eq 0 ]; then
  echo "::notice::no merges pending; nothing to assemble"
  exit 0
fi

# --- collect one entry per merged pull request -------------------------------

entries=''
prs=()
for merge in "${merges[@]}"; do
  pr="$(git log -1 --format='%s' "${merge}" | sed -nE 's|^Merge pull request #([0-9]+) from .*|\1|p')"
  if [ -z "${pr}" ]; then
    echo "::warning::${merge} is a merge commit with no pull-request number in its subject; skipped"
    continue
  fi

  echo "::notice::collecting #${pr}"
  if ! entry="$(.github/scripts/changelog-entry.sh "${pr}")"; then
    echo "::error::#${pr} has no resolvable changelog entry; it should not have merged"
    exit 1
  fi
  entries+="${entry}"$'\n'
  prs+=("#${pr}")
done

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

# The pending entries are consumed, not archived: main never carries a
# .changelog file, so a stale one can never be assembled twice.
if compgen -G "${changelog_dir}/*.md" >/dev/null; then
  find "${changelog_dir}" -name '*.md' ! -name 'README.md' -delete
fi

git config user.name "arda-changelog-bot[bot]"
git config user.email "arda-changelog-bot[bot]@users.noreply.github.com"
git add "${changelog}" "${changelog_dir}"
git commit -m "${assembly_prefix}${next}

Covers ${prs[*]}."
git push origin HEAD:main

git tag -a "v${next}" -m "Release ${next}"
git push origin "v${next}"

gh release create "v${next}" \
  --title "Release ${next}" \
  --notes "$(printf '%s\n\nCovers %s.\n' "${merged}" "${prs[*]}")"
