# Documentation standard

| Field | Value |
|---|---|
| Status | Active |
| Owner | Solution Architect |
| Implements | [ADR 0020](../adr/0020-documentation-site.md) (site and publication), [ADR 0001](../adr/0001-documentation-platform.md) (docs-as-code, superseded in its tool choice) |
| Related | [ADR README](../adr/README.md) (ADR format and lifecycle), [Requirements README](../requirements/README.md) (NFR and business-rule format), [Concepts and their sources](concepts-and-sources.md) |

This standard describes **how** documentation is organised, written, reviewed and published. The decision **that** documentation lives in the repository and is published as a site is recorded in ADR 0001 and ADR 0020; this document is the operating procedure and changes through a normal pull request without a new ADR.

## 1. Where things go

| Folder | Holds | Format and rules |
|---|---|---|
| `docs/adr/` | Architecture decisions: what was chosen, alternatives, consequences | [ADR README](../adr/README.md): MADR 4, lifecycle, weighted evaluation method |
| `docs/requirements/` | Quality requirements (`NFR-*`) and domain rules (`BR-*`) | [Requirements README](../requirements/README.md): identifiers, scenarios, verification |
| `docs/domain/` | Domain knowledge: glossary, model, market facts, worked examples | [Domain README](../domain/README.md): sources with dates, **Inferred** and open questions marked |
| `docs/standards/` | Operating procedures that change without an ADR | A header table (status, owner, what it implements) like this page |
| `README.md` (repository root) | Entry point on GitHub: what the project is, how to build | Short; links into `docs/` |

A page belongs to one folder by what it records: a choice goes to `adr/`, a testable quality to `requirements/`, knowledge to `domain/`, a procedure to `standards/`. When a page starts mixing them, split it.

## 2. Writing rules

- **Language:** English for everything in the repository, so that the site, code and commit history read the same. The one exception is an unlisted page written for a specific Russian-speaking audience (section 6); it says so in a comment at its top.
- **One idea per sentence.** Name things precisely (`price-ticks` topic, not "the queue"); expand abbreviations on first use on each page or link the glossary.
- **Sources:** facts about markets, vendors, standards or concepts cite a primary source with the date checked; concepts link to [Concepts and their sources](concepts-and-sources.md). Text without a source is the author's assessment and says so.
- **Dates** are ISO 8601 (`2026-11-05`). Examples use real calendar dates so they can become tests.
- **Diagrams** are Mermaid code blocks (fence `mermaid`), never images exported from a tool, so that they are reviewed as text. Check that each diagram renders before merging (GitHub preview or local site).
- **Links** are relative between pages (`../adr/0012-message-contract-and-versioning.md#enforcement`), so that they work on GitHub and on the site and are checked by the build. Links to code outside `docs/` use full GitHub URLs.

## 3. Changing documentation

- Documentation changes in the **same pull request** as the code or decision it describes. A pull request that changes behaviour without updating the affected ADR, NFR or domain page is incomplete (self-review checklist in the pull request template).
- A new page is added to `nav` in `zensical.toml` in the same pull request; otherwise it is built but not reachable from the menu.
- ADRs follow their own lifecycle: an Accepted ADR is not edited in substance; a changed decision is a new ADR that supersedes it ([ADR README](../adr/README.md#conventions)).
- Every pull request title references a work item (`AB#<id>`); documentation-only work belongs to a story like any other work.

## 4. Building and previewing locally

Requires Python 3.11 or later ([Zensical on PyPI](https://pypi.org/project/zensical/)). From the repository root:

```powershell
python -m venv .venv-docs
.\.venv-docs\Scripts\Activate.ps1
pip install --require-hashes -r eng/docs/requirements.txt
zensical serve          # preview at http://localhost:8000, rebuilds on save
zensical build --clean  # the same strict build as CI; fails on any broken link or anchor
python eng/docs/remove-unlisted-from-sitemap.py site  # as CI: drop unlisted pages from sitemap.xml
```

`site/` and `.venv-docs/` are not committed.

## 5. Publication and checks

- The `docs` workflow builds the site in strict mode on every pull request that touches `docs/`, `zensical.toml`, `eng/docs/` or the workflow itself, and fails on an invalid link or anchor ([ADR 0020](../adr/0020-documentation-site.md)).
- On merge to `main`, the same workflow deploys the site to GitHub Pages: `https://alexeygane.github.io/signallog/`.
- Dependency updates for the site (Zensical and its packages, GitHub Actions) arrive as Dependabot pull requests and are reviewed like code.

## 6. Unlisted pages

A page meant for a particular reader (a cover note sent with an application, for example) can be published without being listed. Such a page:

- is **not** added to `nav` in `zensical.toml`;
- sets `search: exclude: true` and `robots: noindex, nofollow` in its front matter; the template override `overrides/main.html` turns the second into `<meta name="robots">`;
- is removed from `sitemap.xml` by `eng/docs/remove-unlisted-from-sitemap.py`, which the `docs` workflow runs after the build;
- is not linked from any listed page.

"Unlisted" is not "private": the Markdown source is in the public repository, and anyone with the link can open the page. Nothing that must stay confidential goes on such a page.

| Page | Audience | Language |
|---|---|---|
| `docs/note.md` (`/note/`) | Readers of the project cover note | Russian |
