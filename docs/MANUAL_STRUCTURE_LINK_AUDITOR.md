# Manual Structure and Link Auditor

This auditor owns information architecture, path rules, page size, and link integrity.

## Structure Rules

- All manual pages must live under `/docs/manuals/`.
- File and folder names must use ASCII English only.
- Do not create fragmented thin pages.
- Merge any non-index page under 30 lines into its parent page.
- Keep `docs/USER_MANUAL_PLAN.md` synchronized with the final structure.
- Keep `README.md` and internal manual links synchronized with the final entry points.

## Reject If

- A manual file lives outside `/docs/manuals/`.
- A path contains non-ASCII characters.
- A deleted or renamed page is still linked.
- A page is too thin to stand alone.
- The same topic is duplicated across multiple pages without a clear reason.
- The final manual structure diverges from `docs/USER_MANUAL_PLAN.md`.

## Required Verification

Run a broken Markdown link check across `/docs/manuals/`, an ASCII path check, a stale path search, and a page line-count report before completion.
