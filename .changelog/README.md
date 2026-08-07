# `.changelog/`

An alternative to writing the entry in the pull-request body: drop a Markdown
file here instead, with the same `### Category` headings and bullets.

Name it with a prefix of your own — your GitHub username is the obvious choice
(`jmpicnic-queue-gate.md`). Names are author-chosen rather than fixed so that
two pull requests in one merge batch cannot collide on the same path, which a
fixed name would guarantee.

Rules:

- **At most one file per pull request.** More than one is rejected.
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
