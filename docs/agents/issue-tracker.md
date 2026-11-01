# Issue tracker: GitHub

Issues and specs live in GitHub Issues in `LeonGeorgi/RudolstadtForiOS`.
Use the connected GitHub integration when available and `gh` as fallback.

Follow the approval, priority, type, dependency, and progress rules in
AGENTS.md's "Issue tracking" section. Those rules also apply to issues
created by engineering skills.

## Operations

- Publish a ticket or spec: create a GitHub issue.
- Fetch a ticket: read its body, labels, comments, and dependencies.
- Represent hierarchy with native sub-issues.
- Represent dependencies with native "blocked by" relationships.

For gh operations, specify `--repo LeonGeorgi/RudolstadtForiOS`.
For multiline bodies or comments, write the text to a temporary file
and pass `--body-file`.

## Pull requests as a triage surface

**PRs as a request surface: no.**
