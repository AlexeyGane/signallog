# 0020 — Documentation site: Zensical on GitHub Pages

| Field | Value |
|---|---|
| Status | Proposed |
| Date | 2026-11-05 |
| Deciders | Solution Architect, Key Developer *(both roles held by one person — see README)* |
| Supersedes | [0001](0001-documentation-platform.md) |
| Related | [0002](0002-source-control-platform.md), [0004](0004-ci-cd-platform.md), [0000](0000-cost-optimization-strategy.md) |
| Traces to | [NFR-DOC-01](../requirements/nfr.md#nfr-doc-01); Azure Boards Feature "Documentation site" |

## Context and Problem Statement

[ADR 0001](0001-documentation-platform.md) chose docs-as-code in this repository, published as a static site on GitHub Pages, and named MkDocs with the Material theme as the generator. It recorded as a risk that Material for MkDocs was in maintenance mode and that its maintainers recommended their successor, Zensical. Since then:

- Material for MkDocs receives critical fixes only, now extended to **5 May 2027**; feature development has ended ([Material blog, 2026-02-18, updated 2026-09-16](https://squidfunk.github.io/mkdocs-material/blog/2026/02/18/mkdocs-2.0/)).
- MkDocs 2.0, a rewrite published as a pre-release on 30 August 2026, has no plugin system and a new TOML configuration; according to the Material team, sites built with Material will not work with it. The MkDocs 1.x repository was closed to outside contributions on 2 October 2026 (same source; the Material team is a competitor of MkDocs 2.0, so these statements are read as one party's account).
- **Zensical 0.1.0** was released on 5 November 2026, ending the 0.0.x alpha series. It is MIT-licensed, reads existing MkDocs projects and Python Markdown, and promises deliberate, migrated API changes on the 0.x line ([Zensical, upcoming changes](https://zensical.org/upcoming-changes/), [PyPI](https://pypi.org/project/zensical/)).
- The documentation now has 34 pages (20 ADRs, requirements, domain knowledge, standards) and is ready to be shown, but no site exists yet.

The site itself, the location of the sources and the publication target in ADR 0001 are not in question. The question is: **which generator builds the site, and how is it published and checked?**

## Decision Drivers

- D1 — The existing Markdown pages build without being rewritten (docs-as-code, [0001](0001-documentation-platform.md)).
- D2 — A public site with navigation and search that an employer can browse.
- D3 — Mermaid diagrams render on the site as they do on GitHub.
- D4 — Zero recurring cost ([0000](0000-cost-optimization-strategy.md)).
- D5 — The generator is maintained for the project's horizon (at least two years).
- D6 — A broken internal link or anchor fails the pull request.

## Considered Options

1. **Zensical** with `zensical.toml`, built and deployed by GitHub Actions to GitHub Pages
2. MkDocs 1.x with Material for MkDocs (ADR 0001 as written)
3. MkDocs 2.0
4. DocFX (.NET documentation generator)

## Decision Outcome

**Chosen option:** Option 1, Zensical, because it builds the existing pages unchanged (D1), renders navigation, search and Mermaid out of the box (D2, D3) and is the maintained successor of the toolchain ADR 0001 chose (D5).

### Weighted evaluation

*Expert judgement (one assessor), not a measurement.* Method: [weighted evaluation](README.md#weighted-evaluation-method).

Weights (swing weighting, fixed before scoring):

| Criterion | Driver | Weight | Why this weight |
|---|---|---|---|
| Existing pages build unchanged | D1 | 25 | 34 pages exist; a rewrite would delay the site by days |
| Navigation and search | D2 | 15 | All options produce a usable site; the swing is in quality, not in presence |
| Mermaid renders | D3 | 15 | Several pages carry diagrams; without them those pages lose meaning |
| Maintained for two years | D5 | 30 | The reason for this ADR: ADR 0001's toolchain reaches end of fixes in May 2027 |
| Broken links fail CI | D6 | 15 | Links are dense (ADR ↔ NFR ↔ domain); unchecked, they rot silently |

Scale anchors:

| Criterion | 1 | 3 | 5 |
|---|---|---|---|
| Existing pages build unchanged | Pages or structure must be rewritten | Configuration rewritten, minor page edits | Pages build as they are |
| Navigation and search | No search or flat navigation only | Search and basic navigation | Tabs, sections, section index pages, search |
| Mermaid renders | Not supported | Via plugin or custom script | Built in |
| Maintained for two years | End of fixes announced within the horizon | Maintained, but pre-release or governance in doubt | Actively developed, release line declared |
| Broken links fail CI | No link validation | Links validated, anchors not, or validation not tested here | Links and anchors validated; strict mode fails the build |

| Criterion (weight) | 1. Zensical | 2. MkDocs 1.x + Material | 3. MkDocs 2.0 | 4. DocFX |
|---|---|---|---|---|
| Existing pages build unchanged (25) | 5 ¹ | 5 | 3 | 3 |
| Navigation and search (15) | 5 | 5 | 3 ² | 4 |
| Mermaid renders (15) | 5 | 5 | 3 | 5 ³ |
| Maintained for two years (30) | 4 ⁴ | 1 | 3 | 4 |
| Broken links fail CI (15) | 5 | 5 | 3 | 3 ⁵ |
| **Weighted score** | **4.70** | **3.80** | **3.00** | **3.75** |

¹ Verified on 2026-11-05: `zensical build --strict` over all pages reported two issues, both placeholder links in `template.md`. ² Navigation is passed to themes as pre-rendered HTML, which per the Material team prevents tabs and collapsible sections (one party's account). ³ Built into the `modern` template ([DocFX Markdown](https://dotnet.github.io/docfx/docs/markdown.html)). ⁴ Not 5: the 0.x line is one day old and plugin parity with MkDocs is incomplete. ⁵ Not tested here.

Drivers not scored: D4 (all four produce static files for GitHub Pages at no cost).

Sensitivity: Option 1 scores at least as well as every alternative on every criterion, so no weights change the order. Per the method, what the table leaves out: **maturity risk**. Zensical 0.1.0 is one day old; a breaking change or a missing feature could block a build. The mitigations are under *Consequences*. Effort is not a driver; it is small for Options 1 and 2 and larger for 3 and 4.

### Site and publication

| Element | Decision |
|---|---|
| Configuration | `zensical.toml` in the repository root; `docs_dir = "docs"`, output `site/` (not committed) |
| Navigation | Explicit `nav` in `zensical.toml`: Home, Architecture decisions, Requirements, Domain, Standards. A new page is added to `nav` in the same pull request |
| Diagrams | Mermaid through the `pymdownx.superfences` custom fence; Zensical loads the runtime on pages that contain a diagram ([Zensical, diagrams](https://zensical.org/docs/authoring/diagrams/)) |
| Validation | `[project.validation]` with `invalid_links` and `invalid_link_anchors`, `strict = true`: any issue aborts the build with exit code 1 ([Zensical, validation](https://zensical.org/docs/setup/validation/)) |
| Dependencies | `eng/docs/requirements.in` names `zensical==0.1.0`; `eng/docs/requirements.txt` pins every transitive package with hashes and is installed with `pip install --require-hashes`. Dependabot (`pip` ecosystem, `/eng/docs`) proposes updates; a new Zensical minor version is a reviewed pull request, as for GitHub Actions ([0004](0004-ci-cd-platform.md)). If an update cannot regenerate the hashed file, it is regenerated with the command at the top of `requirements.in` |
| Workflow | `.github/workflows/docs.yml`: on pull requests touching the site, build in strict mode; on push to `main`, build and deploy with `actions/upload-pages-artifact` and `actions/deploy-pages`, every action pinned to a full-length commit SHA ([0004](0004-ci-cd-platform.md)). The structure follows Zensical's published workflow ([Zensical, publish your site](https://zensical.org/docs/publish-your-site/)) |
| Hosting | GitHub Pages, source "GitHub Actions"; URL `https://alexeygane.github.io/signallog/` |
| Structure and writing rules | [Documentation standard](../standards/documentation.md) (a standard, not a decision) |

### Consequences

- Good, because the site can be published now, from the pages that exist, with link and anchor checks enforced in CI.
- Good, because the toolchain is the maintained successor of the one ADR 0001 chose; the Markdown and the Mermaid fence syntax stay MkDocs-compatible.
- Bad, because Zensical 0.x is young: the plugin set is smaller than MkDocs', and options may change between minor versions.
- Risk: a Zensical release breaks the build (mitigation: exact version with hashes, upgrades only through reviewed pull requests; until 5 May 2027 the same pages build with Option 2 by adding an equivalent `mkdocs.yml`).
- Bad, because the Mermaid runtime is loaded in the reader's browser from the unpkg CDN (observed in the built pages: `https://unpkg.com/mermaid@12/...`): diagrams depend on a third-party host, and readers' browsers contact it. Accepted for a public portfolio site; revisit if the site must work offline or under a strict content security policy.
- Risk: the site exposes a page that should stay internal (mitigation: everything under `docs/` is already public in the repository; the site adds no new content).

### Confirmation

- The `docs` job runs on every pull request that changes `docs/`, `zensical.toml`, `eng/docs/` or the workflow, and fails on any invalid link or anchor.
- After merge to `main`, the site at `https://alexeygane.github.io/signallog/` shows the change.
- `eng/docs/requirements.txt` contains hashes for every package; the workflow installs with `--require-hashes`.

## Pros and Cons of the Options

### 1. Zensical
- Good, because existing pages build unchanged and validation of links and anchors is built in.
- Bad, because the 0.x line has just started.

### 2. MkDocs 1.x with Material for MkDocs
- Good, because it is mature and widely used.
- Bad, because critical fixes end on 5 May 2027 and MkDocs 1.x no longer accepts outside contributions.

### 3. MkDocs 2.0
- Good, because it continues the MkDocs name under its original maintainers.
- Bad, because it is a pre-release without plugins, with a new configuration format and, per the Material team, no Material support.

### 4. DocFX
- Good, because it is .NET-native and can generate API reference from the C# code later.
- Bad, because it needs its own configuration and table-of-contents files, and its strengths (API reference) are not what this site needs now.

## More Information

- Review triggers: a Zensical release that changes configuration or Markdown behaviour; API reference from code becomes a requirement (reconsider DocFX for that part); Zensical development stops.
- Sources checked 2026-11-05: [Material for MkDocs blog — What MkDocs 2.0 means](https://squidfunk.github.io/mkdocs-material/blog/2026/02/18/mkdocs-2.0/); [Material for MkDocs blog — Zensical](https://squidfunk.github.io/mkdocs-material/blog/2025/11/05/zensical/); [Zensical — upcoming changes](https://zensical.org/upcoming-changes/); [Zensical on PyPI](https://pypi.org/project/zensical/); [Zensical — publish your site](https://zensical.org/docs/publish-your-site/); [Zensical — validation](https://zensical.org/docs/setup/validation/); [Zensical — diagrams](https://zensical.org/docs/authoring/diagrams/); [DocFX — Markdown](https://dotnet.github.io/docfx/docs/markdown.html).
