# 0021 — Citation and reference model: one bibliography, shortened footnotes

| Field | Value |
|---|---|
| Status | Accepted 2026-11-19 |
| Date | 2026-11-19 |
| Deciders | Solution Architect, Key Developer *(both roles held by one person — see README)* |
| Supersedes | — |
| Related | [0001](0001-documentation-platform.md), [0004](0004-ci-cd-platform.md), [0020](0020-documentation-site.md) |
| Traces to | [NFR-DOC-01](../requirements/nfr.md#nfr-doc-01); Azure Boards Feature #42 "Citations and references" |

## Context and Problem Statement

The project already requires sources. The [documentation standard](../standards/documentation.md#2-writing-rules), the [ADR conventions](README.md#conventions) and the [domain conventions](../domain/README.md#conventions-for-these-pages) say that every fact about a market, a vendor, a standard or a concept cites a primary source with the date it was checked, and that a concept links to [Concepts and their sources](../standards/concepts-and-sources.md). The rules say **what** must be cited, not **how**, and an audit of `main` at commit `7c618c2` on 2026-11-19 shows the cost:

- The documentation and the code contain 187 distinct external URLs in 295 places; 52 of them appear in more than one file. The ICE specification of the TTF daily futures appears in four files under three different titles. One ICE product page carries "checked 2026-10-30 and 2026-11-07" on one page and "checked 2026-11-06" on another.
- Sources are written in six formats: "Title — URL (checked …)", "Title: URL", "Author, [Title](URL): what it supports", a "Source:" line after a paragraph, a link in running text, and a table cell.
- Long source lists stand at the end of a page without pointers from the text: `market-data-sources.md` lists 20 sources, and a reader cannot tell which sentence rests on which.
- 14 of the 31 entries of the concepts page are not linked from any page by their anchor, and one entry is used nowhere. The glossary has anchors only for its sections, not for its 69 terms.
- Links from code to the site use anchors generated from numbered headings (`#6-two-layers`), and the strict build does not check them.
- The `footnotes` extension is not enabled: the explicit list of extensions in `zensical.toml` replaces the default set.

The question is: **how do pages, Russian mirrors and code refer to concepts, facts and external sources, so that every claim can be traced to a source, each source is described and checked in one place, the text stays readable and the build can verify it?**

## Decision Drivers

- D1 — One place per source: its URL, version, date checked and archived copy are kept once. Links decay: of the web pages that existed in 2013, 38 % could no longer be reached a decade later.[^chapekis-2024]
- D2 — Claim-level traceability: a reader sees which sentence rests on which source.
- D3 — Readable text: a citation does not interrupt reading.
- D4 — Stable identifiers: a citation survives reordered paragraphs and renamed headings.
- D5 — Several sources for one concept, each with its role (where the concept comes from, its current definition, further reading).
- D6 — Works with Zensical 0.1.1 and on GitHub without plugins.
- D7 — A broken or unused citation fails CI. Wikipedia, for example, reports a list-defined reference that the text does not use as an error.[^wikipedia-list-defined-references]
- D8 — One rule for pages, Russian mirrors and code.

## Considered Options

1. **Source lists per page in one format** (the status quo, normalised)
2. **Full citations in footnotes on every page**, as in ordinary Wikipedia footnotes or numbered journal references[^nature-final-submission]
3. **Pandoc citation keys** (`[@key]`) with a bibliography plugin[^quarto-citations]
4. **Shortened footnotes**: a footnote whose label is a key and whose text links to one bibliography, with registers for terms and concepts[^wikipedia-shortened-footnotes]

## Decision Outcome

**Chosen option:** Option 4, shortened footnotes with one bibliography, because it is the only option that keeps each source in one place (D1) and ties it to the sentence it supports (D2) with what Zensical 0.1.1 and GitHub render today (D6).

### Evaluation

*Expert judgement (one assessor), not a measurement.* The options differ on whether a driver is met at all, so the table shows that instead of weighted scores.

| Driver | 1. Lists per page | 2. Full footnotes | 3. Pandoc keys | 4. Shortened footnotes |
|---|---|---|---|---|
| D1 One place per source | No: 52 URLs stay in several files | No: the copies move into footnotes | Yes | Yes |
| D2 Claim-level traceability | No | Yes | Yes | Yes |
| D4 Stable identifiers | No identifier | Labels per page only | Yes | Yes |
| D6 Zensical 0.1.1 and GitHub | Yes | Yes, once `footnotes` is enabled | No ¹ | Yes ² |
| D7 Checked in CI | Format only | Partly | Yes | Yes ³ |

¹ Zensical does not run MkDocs plugins it does not implement; their configuration is silently ignored, and no bibliography plugin is implemented.[^zensical-mkdocs-plugins] GitHub would show `[@key]` as text. ² Verified on 2026-11-19 with Zensical 0.1.1: footnotes render with the extension enabled, a footnote label can be the source key, and one footnote can be referenced twice on a page. GitHub has rendered Markdown footnotes since 2021-09-30.[^gh-2021-09-30-footnotes] ³ Verified on 2026-11-19: `zensical build --strict` fails when a footnote links to an anchor that the bibliography page does not have. A footnote that is defined but never referenced is rendered without a warning, so a script checks that.

Drivers not scored: D3 (every option keeps URLs out of the running text or can do so), D5 and D8 (the registers and the rules for code can be added to any option).

Sensitivity: Option 4 meets every scored driver, so no weighting changes the order. Per the method, what the table leaves out: **effort**. Option 1 costs least; Option 4 needs a generator, a checker and the migration of the 295 places that cite a URL. The migration is split into small stories, and each story moves only its own pages.

### The model

| Element | Decision |
|---|---|
| Bibliography | `docs/references/sources.toml`: one entry per external source with a stable key, CSL field names[^csl-1-0-2], `accessed`, an optional `archive`, `tier` (1 primary, 2 vendor documentation, 3 news) and `stability` (`pinned` or `living`). `eng/docs/build_references.py` writes the page `docs/references/index.md` and checks it with `--check` |
| Data format | TOML, read with `tomllib` from the Python standard library (Python 3.11 and later, already required by the documentation standard)[^python-tomllib]; no new hashed package |
| Citation in text | A Markdown footnote at the end of the passage it supports. Its label is the key; its text links to the bibliography entry and gives a locator (section, page, table). Pages carry no external URLs |
| Terms and concepts | The [glossary](../domain/glossary.md) (domain terms) and the [concepts register](../standards/concepts-and-sources.md) (engineering concepts) are linked at the first use on a page. The register lists the sources of a concept by role |
| Roles of sources | Origin, definition, evidence, method or data, further reading, disputes. They follow the IETF split into normative and informative references[^iesg-2006-04-19-references] and the citation types of CiTO[^dcmi-cito][^willighagen-2020] |
| Dates | The date a source was checked lives only in the bibliography. The date on which a fact holds stays in the text when it is part of the claim |
| Code | Decisions and requirements by identifier (`ADR 0012`, `NFR-SEC-03`); principles by `<seealso href>` to an explicit anchor of the site; sources by key in brackets (`[steele-2014]`); no external URLs |
| Anchors | `<a id="…"></a>` for anything linked from outside a page: GitHub shows the `{#id}` syntax as text |
| Checks | Strict build; `eng/docs/check_references.py` in the `docs` workflow; a weekly external link check |
| Procedure | [References standard](../standards/references.md) |

### Consequences

- Good, because a source is re-checked by editing one entry, and the text carries a superscript number with a tooltip instead of a URL and a date.[^zensical-footnotes]
- Good, because links from code become a contract: an explicit anchor that CI checks against the built site.
- Good, because the bibliography is data with CSL field names, so it can move to Pandoc, Zotero or a future Zensical module without being retyped.
- Bad, because a reader is one click further from the URL: text → footnote → bibliography.
- Bad, because adding a source takes an entry and a footnote instead of one line.
- Risk: the migration changes what a page says (mitigation: pull requests that change citations only, file-by-file review, and a legacy list of pages not yet migrated that only shrinks).
- Converting the citations of an Accepted ADR to this model is an editorial change and needs no superseding ADR; the references standard says so.

### Confirmation

- `zensical build --strict` fails on a footnote that links to a missing bibliography entry.
- `eng/docs/check_references.py` in the `docs` workflow reports unused footnotes, external URLs outside the bibliography, entries cited nowhere, Russian mirrors with other keys than their English page, and links from code to pages or anchors that do not exist. Pages in the legacy list get warnings until they are migrated; then every finding is an error.
- A scheduled workflow checks the URLs of the bibliography every week.
- Review trigger: Zensical opens its module API or ships a bibliography or citation module.

## Pros and Cons of the Options

### 1. Source lists per page
- Good, because it is the smallest change.
- Bad, because the duplicated URLs and the conflicting dates stay, and a sentence still has no pointer to its source.

### 2. Full citations in footnotes on every page
- Good, because every sentence points to its source.
- Bad, because the full description of a source is repeated on every page that cites it.

### 3. Pandoc citation keys with a plugin
- Good, because it is the key-based citation syntax of Pandoc, which Quarto also uses.
- Bad, because Zensical does not run the plugin, and GitHub shows the keys as raw text.

### 4. Shortened footnotes with one bibliography
- Good, because it meets D1, D2 and D6 with tools the site already has.
- Bad, because it needs a generator, a checker and a migration.

## More Information

- Related decisions: [ADR 0001](0001-documentation-platform.md) (documentation in the repository), [ADR 0004](0004-ci-cd-platform.md) (CI), [ADR 0020](0020-documentation-site.md) (the site and its strict build).
- Implementation: Azure Boards Feature #42 "Citations and references", stories AB#43 to AB#55. The sources of this ADR are entries of the [bibliography](../references/index.md); they were checked on 2026-11-19.

[^chapekis-2024]: [Chapekis et al. 2024](../references/index.md#chapekis-2024), Pew Research Center: 38 % of pages from 2013 no longer accessible; 54 % of Wikipedia pages with at least one dead link in References.
[^wikipedia-list-defined-references]: [Wikipedia, Help:List-defined references](../references/index.md#wikipedia-list-defined-references).
[^nature-final-submission]: [Nature, Final submission](../references/index.md#nature-final-submission): references numbered in order of appearance.
[^quarto-citations]: [Quarto, Citations](../references/index.md#quarto-citations): the Pandoc `[@key]` syntax.
[^wikipedia-shortened-footnotes]: [Wikipedia, Help:Shortened footnotes](../references/index.md#wikipedia-shortened-footnotes): Wikipedia keeps the full citations on the same page; this model keeps them in one bibliography for all pages.
[^zensical-mkdocs-plugins]: [Zensical, MkDocs plugins](../references/index.md#zensical-mkdocs-plugins).
[^gh-2021-09-30-footnotes]: [GitHub Changelog, 2021-09-30](../references/index.md#gh-2021-09-30-footnotes).
[^csl-1-0-2]: [CSL 1.0.2 specification](../references/index.md#csl-1-0-2), appendices III (types) and IV (variables).
[^python-tomllib]: [Python, tomllib](../references/index.md#python-tomllib): added in Python 3.11; reads TOML and does not write it.
[^iesg-2006-04-19-references]: [IESG statement, 2006-04-19](../references/index.md#iesg-2006-04-19-references).
[^dcmi-cito]: [CiTO](../references/index.md#dcmi-cito).
[^willighagen-2020]: [Willighagen 2020](../references/index.md#willighagen-2020): `usesMethodIn`, `usesDataFrom`, `disagreesWith` in a journal's practice.
[^zensical-footnotes]: [Zensical, Footnotes](../references/index.md#zensical-footnotes): the feature `content.footnote.tooltips`.
