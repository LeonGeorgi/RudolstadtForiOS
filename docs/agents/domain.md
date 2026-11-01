# Domain docs

This repository uses a single-context layout:

- `GLOSSARY.md` at the repository root defines domain vocabulary.
- `docs/adr/` contains architecture decision records.

Before exploring the domain, read the glossary and ADRs relevant to
the work. If they are absent, proceed silently. Create them lazily
through domain-modeling when terms or decisions are resolved.

Use the glossary's vocabulary in issues, proposals, code, and tests.
If a needed concept is missing, reconsider the wording or note the
gap for domain-modeling.

Surface conflicts with an existing ADR explicitly, referencing the
decision and explaining why it may need revisiting.
