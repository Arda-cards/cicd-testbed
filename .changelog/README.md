# `.changelog/`

An alternative to writing the entry in the pull-request body: drop a Markdown
file here instead, with the same `### Category` headings and bullets.

Name it with a prefix of your own — your GitHub username is the obvious choice
(`jmpicnic-queue-gate.md`). Names are author-chosen rather than fixed so that
two pull requests in one merge batch cannot collide on the same path, which a
fixed name would guarantee.

Rules:

- **At most one file per pull request.** More than one is rejected. Note that
  this is a property of the *pull request*, not of the directory: a merge batch
  legitimately stages several branches' files side by side, and a build that
  counted files there failed on every batch.
- **One route, not both.** A file *or* a `## CHANGELOG` section in the pull
  request — never both, and never neither.
- **`main` never carries one.** Assembly consumes these files when it composes
  the release block, so a stale entry cannot be published twice.

Optional frontmatter configures the pipeline rather than the release notes, and
is stripped before anything reaches `CHANGELOG.md`:

```markdown
---
feature-build: jmpicnic-1408
---

### Added

- What the change enables.
```

The marker lives in **whichever manifest the branch carries**. Using the body
route instead, it is a `feature-build:` line inside the `## CHANGELOG` section:

```markdown
## CHANGELOG

feature-build: jmpicnic-1408

### Added

- What the change enables.
```

Exactly one manifest is permitted, so exactly one marker location exists and
there is nothing to disambiguate. A branch with **no open pull request** must
use the file: there is no body to read. Closing a pull request takes a body
marker with it, and the next push builds ordinarily — a branch that needs its
marker to outlive a pull request should use the file.

A marked pull request cannot merge. Remove the marker first.
